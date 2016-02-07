require 'pathname'
require 'erubis'
require 'json'

module ZendeskAppsSupport
  class Package
    include ZendeskAppsSupport::BuildTranslation

    REQUIREMENTS_FILENAME = "requirements.json"

    DEFAULT_LAYOUT = Erubis::Eruby.new(File.read(File.expand_path('../assets/default_template.html.erb', __FILE__)))
    DEFAULT_SCSS   = File.read(File.expand_path('../assets/default_styles.scss', __FILE__))
    SRC_TEMPLATE   = Erubis::Eruby.new(File.read(File.expand_path('../assets/src.js.erb', __FILE__)))

    LEGACY_URI_STUB = '_legacy'

    attr_reader :lib_root, :root, :warnings

    def initialize(dir, is_cached = true)
      @root     = Pathname.new(File.expand_path(dir))
      @lib_root = Pathname.new(File.join(root, 'lib'))

      @is_cached = is_cached # disabled by ZAT for development
      @warnings = []
    end

    def validate(marketplace: true)
      [].tap do |errors|
        errors << Validations::Marketplace.call(self) if marketplace

        errors << Validations::Manifest.call(self)

        if has_manifest?
          errors << Validations::Source.call(self)
          errors << Validations::Translations.call(self)

          unless manifest_json['requirementsOnly']
            errors << Validations::Templates.call(self)
            errors << Validations::Stylesheets.call(self)
          end

          if has_requirements?
            errors << Validations::Requirements.call(self)
          end
        end

        if has_banner?
          errors << Validations::Banner.call(self)
        end

        errors.flatten!.compact!
      end
    end

    def validate!(marketplace: true)
      errors = validate(marketplace: marketplace)
      if errors.any?
        raise errors.first
      end
      true
    end

    def assets
      @assets ||= Dir.chdir(root) do
        Dir['assets/**/*'].select { |f| File.file?(f) }
      end
    end

    def path_to(file)
      File.join(root, file)
    end

    def requirements_path
      path_to(REQUIREMENTS_FILENAME)
    end

    def locales
      translations.keys
    end

    def files
      files = []
      Dir[root.join('**/**')].each do |f|
        next unless File.file?(f)
        relative_file_name = f.sub(/#{root}\/?/, '')
        next if relative_file_name =~ /^tmp\//
        files << AppFile.new(self, relative_file_name)
      end
      files
    end

    def js_files
      @js_files ||= files.select { |f| f.to_s == 'app.js' || ( f.to_s.start_with?('lib/') && f.to_s.end_with?('.js') ) }
    end

    def lib_files
      @lib_files ||= js_files.select { |f| f =~ /^lib\// }
    end

    def template_files
      files.select { |f| f =~ /^templates\/.*\.hdbs$/ }
    end

    def translation_files
      files.select { |f| f =~ /^translations\// }
    end

    def compile_js(options)
      begin
        app_id = options.fetch(:app_id)
        asset_url_prefix = options.fetch(:assets_dir)
        name = options.fetch(:app_name)
      rescue KeyError => e
        raise ArgumentError, e.message
      end

      locale = options.fetch(:locale, 'en')

      source = iframe_only? ? nil : app_js
      version = manifest_json['version']
      app_class_name = "app-#{app_id}"
      author = manifest_json['author']
      framework_version = manifest_json['frameworkVersion']
      single_install = manifest_json['singleInstall'] || false
      templates = is_no_template ? {} : compiled_templates(app_id, asset_url_prefix)

      app_settings = {
        location: locations,
        noTemplate: is_no_template,
        singleInstall: single_install
      }.select { |_k, v| !v.nil? }

      SRC_TEMPLATE.result(
        name: name,
        version: version,
        source: source,
        app_settings: app_settings,
        asset_url_prefix: asset_url_prefix,
        app_class_name: app_class_name,
        author: author,
        translations: translations_for(locale),
        framework_version: framework_version,
        templates: templates,
        modules: commonjs_modules,
        iframe_only: iframe_only?
      )
    end

    def manifest_json
      @manifest ||= read_json('manifest.json')
    end

    def requirements_json
      return nil unless has_requirements?
      @requirements ||= read_json('requirements.json')
    end

    def is_no_template
      if manifest_json['noTemplate'].is_a?(Array)
        false
      else
        !!manifest_json['noTemplate']
      end
    end

    def no_template_locations
      if manifest_json['noTemplate'].is_a?(Array)
        manifest_json['noTemplate']
      else
        !!manifest_json['noTemplate']
      end
    end

    def compiled_templates(app_id, asset_url_prefix)
      compiled_css = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + app_css, app_id, asset_url_prefix).compile

      layout = templates['layout'] || DEFAULT_LAYOUT.result

      templates.tap do |templates|
        templates['layout'] = "<style>\n#{compiled_css}</style>\n#{layout}"
      end
    end

    def market_translations!(locale)
      result = translations[locale].fetch('app', {})
      result.delete('name')
      result.delete('description')
      result.delete('long_description')
      result.delete('installation_instructions')
      result
    end

    def has_location?
      manifest_json['location']
    end

    def has_file?(path)
      File.exist?(path_to(path))
    end

    def app_css
      css_file = path_to('app.css')
      scss_file = path_to('app.scss')
      File.exist?(scss_file) ? File.read(scss_file) : ( File.exist?(css_file) ? File.read(css_file) : '' )
    end

    def locations
      locations = manifest_json['location']
      if locations.is_a?(Hash)
        locations
      elsif locations.is_a?(Array)
        { 'zendesk' => Hash[locations.map { |location| [ location, LEGACY_URI_STUB ] }] }
      else # String
        { 'zendesk' => { locations => LEGACY_URI_STUB } }
      end
    end

    def iframe_only?
      !legacy_non_iframe_app?
    end

    private

    def legacy_non_iframe_app?
      @non_iframe ||= locations.values.flat_map(&:values).any? { |l| l == LEGACY_URI_STUB }
    end

    def templates
      templates_dir = File.join(root, 'templates')
      Dir["#{templates_dir}/*.hdbs"].inject({}) do |memo, file|
        str = File.read(file)
        str.chomp!
        memo[File.basename(file, File.extname(file))] = str
        memo
      end
    end

    def translations_for(locale)
      trans = translations
      return trans[locale] if trans[locale]
      trans[self.manifest_json['defaultLocale']]
    end

    def translations
      return @translations if @is_cached && @translations

      @translations = begin
        translation_dir = File.join(root, 'translations')
        return {} unless File.directory?(translation_dir)

        locale_path = "#{translation_dir}/#{self.manifest_json['defaultLocale']}.json"
        default_translations = process_translations(locale_path)

        Dir["#{translation_dir}/*.json"].inject({}) do |memo, path|
          locale = File.basename(path, File.extname(path))

          locale_translations = if locale == self.manifest_json['defaultLocale']
            default_translations
          else
            deep_merge_hash(default_translations, process_translations(path))
          end

          memo[locale] = locale_translations
          memo
        end
      end
    end

    def process_translations(locale_path)
      translations = File.exist?(locale_path) ? JSON.parse(File.read(locale_path)) : {}
      translations['app'].delete('package') if translations.has_key?('app')
      remove_zendesk_keys(translations)
    end

    def has_lib_js?
      lib_files.any?
    end

    def has_manifest?
      has_file?('manifest.json')
    end

    def has_requirements?
      has_file?('requirements.json')
    end

    def has_banner?
      has_file?('assets/banner.png')
    end

    def app_js
      read_file('app.js')
    end

    def commonjs_modules
      return {} unless has_lib_js?

      lib_files.each_with_object({}) do |file, modules|
        name          = file.relative_path.gsub(/^lib\//, '')
        content       = file.read
        modules[name] = content
      end
    end

    def deep_merge_hash(h, another_h)
      result_h = h.dup
      another_h.each do |key, value|
        if h.has_key?(key) && h[key].is_a?(Hash) && value.is_a?(Hash)
          result_h[key] = deep_merge_hash(h[key], value)
        else
          result_h[key] = value
        end
      end
      result_h
    end

    def read_file(path)
      File.read(path_to(path))
    end

    def read_json(path)
      file = read_file(path)
      unless file.nil?
        JSON.parse(read_file(path))
      end
    end
  end
end
