# frozen_string_literal: true
require 'pathname'
require 'erubis'
require 'json'

module ZendeskAppsSupport
  class Package
    extend Gem::Deprecate
    include ZendeskAppsSupport::BuildTranslation

    MANIFEST_FILENAME = 'manifest.json'
    REQUIREMENTS_FILENAME = 'requirements.json'

    DEFAULT_LAYOUT = Erubis::Eruby.new(File.read(File.expand_path('../assets/default_template.html.erb', __FILE__)))
    DEFAULT_SCSS   = File.read(File.expand_path('../assets/default_styles.scss', __FILE__))
    SRC_TEMPLATE   = Erubis::Eruby.new(File.read(File.expand_path('../assets/src.js.erb', __FILE__)))

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
          errors << Validations::Requirements.call(self)

          if !manifest.requirements_only? && manifest.marketing_only?
            errors << Validations::Templates.call(self)
            errors << Validations::Stylesheets.call(self)
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

      source = manifest.iframe_only? ? nil : app_js
      app_class_name = "app-#{app_id}"
      # if no_template is an array, we still need the templates
      templates = manifest.no_template == true ? {} : compiled_templates(app_id, asset_url_prefix)

      app_settings = {
        location: manifest.locations,
        noTemplate: manifest.no_template_locations,
        singleInstall: manifest.single_install?,
        signedUrls: manifest.signed_urls?
      }.select { |_k, v| !v.nil? }

      SRC_TEMPLATE.result(
        name: name,
        version: manifest.version,
        source: source,
        app_settings: app_settings,
        asset_url_prefix: asset_url_prefix,
        app_class_name: app_class_name,
        author: manifest.author,
        translations: runtime_translations(translations_for(locale)),
        framework_version: manifest.framework_version,
        templates: templates,
        modules: commonjs_modules,
        iframe_only: manifest.iframe_only?
      )
    end

    def manifest_json
      @manifest_json ||= read_json(MANIFEST_FILENAME)
    end
    deprecate :manifest_json, :manifest, 2016, 9

    def manifest
      @manifest ||= Manifest.new(read_file(MANIFEST_FILENAME))
    end

    def requirements_json
      return nil unless has_requirements?
      @requirements ||= read_json(REQUIREMENTS_FILENAME)
    end

    def is_no_template
      manifest.no_template?
    end
    deprecate :is_no_template, 'manifest.no_template?', 2016, 9

    def no_template_locations
      manifest.no_template_locations
    end
    deprecate :no_template_locations, 'manifest.no_template_locations', 2016, 9

    def compiled_templates(app_id, asset_url_prefix)
      compiled_css = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + app_css, app_id, asset_url_prefix).compile

      layout = templates['layout'] || DEFAULT_LAYOUT.result

      templates.tap do |templates|
        templates['layout'] = "<style>\n#{compiled_css}</style>\n#{layout}"
      end
    end

    def translations_for(locale)
      trans = translations
      return trans[locale] if trans[locale]
      trans[manifest.default_locale]
    end

    def has_location?
      manifest.location?
    end
    deprecate :has_location?, 'manifest.location?', 2016, 9

    def has_file?(path)
      File.exist?(path_to(path))
    end

    def has_requirements?
      has_file?(REQUIREMENTS_FILENAME)
    end

    def app_css
      css_file = path_to('app.css')
      scss_file = path_to('app.scss')
      File.exist?(scss_file) ? File.read(scss_file) : ( File.exist?(css_file) ? File.read(css_file) : '' )
    end

    def locations
      manifest.locations
    end
    deprecate :locations, 'manifest.locations', 2016, 9

    def iframe_only?
      manifest.iframe_only?
    end
    deprecate :iframe_only?, 'manifest.iframe_only?', 2016, 9

    private

    def runtime_translations(translations)
      result = translations.dup
      result.delete('name')
      result.delete('description')
      result.delete('long_description')
      result.delete('installation_instructions')
      result
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

    def translations
      return @translations if @is_cached && @translations

      @translations = begin
        translation_dir = File.join(root, 'translations')
        return {} unless File.directory?(translation_dir)

        locale_path = "#{translation_dir}/#{manifest.default_locale}.json"
        default_translations = process_translations(locale_path)

        Dir["#{translation_dir}/*.json"].inject({}) do |memo, path|
          locale = File.basename(path, File.extname(path))

          locale_translations = if locale == manifest.default_locale
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
      has_file?(MANIFEST_FILENAME)
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

    def read_json(path, parser_opts = {})
      file = read_file(path)
      unless file.nil?
        JSON.parse(read_file(path), parser_opts)
      end
    end
  end
end
