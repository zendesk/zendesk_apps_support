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

    attr_reader :lib_root, :root, :warnings
    attr_accessor :requirements_only

    def initialize(dir)
      @root = Pathname.new(File.expand_path(dir))
      @lib_root = Pathname.new(File.join(@root, 'lib'))
      @dir = @root
      @source_path   = File.join(@root, 'app.js')
      @css_path      = File.join(@root, 'app.css')
      @manifest_path = File.join(@root, 'manifest.json')
      @warnings = []
      @requirements_only = false
    end

    def validate
      [].tap do |errors|
        errors << Validations::Manifest.call(self)

        if has_manifest?
          errors << Validations::Source.call(self)
          errors << Validations::Translations.call(self)

          unless @requirements_only
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

        errors.flatten!
      end
    end

    # This -production- function is used after unzipping the zip file in ZAM.
    # Shouldn't be used for -dev-
    def validate!
      if Dir["#{@root}/**/{*,.*}"].any? { |f| File.symlink?(f) }
        raise Validations::ValidationError.new('Symlinks are not allowed in the zip file')
      end

      errors = self.validate
      raise Validations::ValidationError.new(errors.compact.first) if errors.any?
      true
    end

    def app_js
      read_file('app.js')
    end

    def commonjs_modules
      return {} unless has_lib_js?

      lib_files.each_with_object({}) do |file, modules|
        name          = file.relative_path.gsub!(/^lib\//, '')
        content       = file.read
        modules[name] = content
      end
    end

    def files
      non_tmp_files
    end

    def lib_files
      @lib_files ||= files.select { |f| f =~ /^lib\/.*\.js$/ }
    end

    def template_files
      files.select { |f| f =~ /^templates\/.*\.hdbs$/ }
    end

    def no_template
      manifest = manifest_json
      if manifest_json[:noTemplate].is_a?(Array)
        false
      else
        !!manifest_json[:noTemplate]
      end
    end

    def name
      manifest_json[:name] || 'Local App'
    end

    def location
      manifest_json[:location]
    end

    def no_template_locations
      if manifest_json[:noTemplate].is_a?(Array)
        manifest_json[:noTemplate]
      else
        !!manifest_json[:noTemplate]
      end
    end

    def default_locale
      manifest_json[:defaultLocale]
    end

    def version
      manifest_json[:version]
    end

    def framework_version
      manifest_json[:frameworkVersion]
    end

    def remote_installation_url
      manifest_json[:remoteInstallationURL]
    end

    def terms_conditions_url
      manifest_json[:termsConditionsURL]
    end

    def author
      {
        name: manifest_json[:author][:name],
        email: manifest_json[:author][:email],
        url: manifest_json[:author][:url]
      }
    end

    def locales
      translations.keys
    end

    def parameters
      manifest['parameters'] || {}
    end

    def requirements_path
      path_to(REQUIREMENTS_FILENAME)
    end

    def assets
      @assets ||= begin
                    pwd = Dir.pwd
                    Dir.chdir(@dir)
                    assets = Dir["assets/**/*"].select { |f| File.file?(f) }
                    Dir.chdir(pwd)
                    assets
                  end
    end

    def path_to(file)
      File.join(@dir, file)
    end


    def css
      @css ||= begin
                 File.read(@css_path)
               rescue Errno::ENOENT
                 ''
               end
    end

    def single_install
      !!manifest_json[:singleInstall]
    end

    def manifest
      read_json('manifest.json', false)
    end

    def manifest_json
      read_json('manifest.json')
    end

    def requirements_json
      read_json('requirements.json')
    end

    def templates
      @templates ||= begin
                       templates_dir = File.join(@dir, 'templates')
                       Dir["#{templates_dir}/*.hdbs"].inject({}) do |h, file|
                         str = File.read(file)
                         str.chomp!
                         h[File.basename(file, File.extname(file))] = str
                         h
                       end
                     end
    end

    def translations
      @translations ||= begin
        translation_dir = File.join(@dir, 'translations')
        return {} unless File.directory?(translation_dir)

        locale_path = "#{translation_dir}/#{self.default_locale}.json"
        default_translations = process_translations(locale_path)
        Dir["#{translation_dir}/*.json"].inject({}) do |h, tr|
          locale              = File.basename(tr, File.extname(tr))
          locale_translations = if locale == self.default_locale
                                  default_translations
                                else
                                  default_translations.deep_merge(process_translations(tr))
                                end
          h[locale] = locale_translations
          h
        end
      end
    end

    def translation_files
      files.select { |f| f =~ /^translations\// }
    end

    def market_translations(locale)
      result = translations[locale].try(:[], 'app') || {}
      result.delete('name')
      result.delete('description')
      result.delete('long_description')
      result.delete('installation_instructions')
      result
    end

    def process_translations(locale_path)
      translations = File.exist?(locale_path) ? JSON.parse(File.read(locale_path)) : {}
      translations['app'].delete('package') if translations.has_key?('app')
      remove_zendesk_keys(translations)
    end

    def app_translations(locale)
      remove_zendesk_keys(translations[locale])
    end

    def readified_js(app_id, asset_url_prefix, locale = 'en')
      manifest = manifest_json
      source = app_js
      location = manifest[:location]
      version = manifest[:version]
      app_class_name = "app-#{app_id}"
      author = manifest[:author]
      framework_version = manifest[:frameworkVersion]
      single_install = manifest[:singleInstall] || false
      templates = no_template ? {} : compiled_templates(app_id, asset_url_prefix)

      app_settings = {
        location: location,
        noTemplate: no_template,
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
          translations: translations[locale],
          framework_version: framework_version,
          templates: templates,
          modules: commonjs_modules
      )
    end

    def customer_css
      css_file = file_path('app.css')
      File.exist?(css_file) ? File.read(css_file) : ''
    end

    def has_js?
      file_exists?('app.js')
    end

    def has_lib_js?
      lib_files.any?
    end

    def has_manifest?
      file_exists?('manifest.json')
    end

    def has_location?
      manifest_json[:location]
    end

    def has_requirements?
      file_exists?('requirements.json')
    end

    def has_banner?
      file_exists?('assets/banner.png')
    end

    def file_path(path)
      File.join(root, path)
    end

    def compiled_templates(app_id, asset_url_prefix)
      compiled_css = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + customer_css, app_id, asset_url_prefix).compile

      templates = begin
        Dir["#{root}/templates/*.hdbs"].inject({}) do |h, file|
          str = File.read(file)
          str.chomp!
          h[File.basename(file, File.extname(file))] = str
          h
        end
      end

      layout = templates['layout'] || DEFAULT_LAYOUT.result

      templates.tap do |templates|
        templates['layout'] = "<style>\n#{compiled_css}</style>\n#{layout}"
      end
    end

    private

    def non_tmp_files
      files = []
      Dir[root.join('**/**')].each do |f|
        next unless File.file?(f)
        relative_file_name = f.sub(/#{root}\/?/, '')
        next if relative_file_name =~ /^tmp\//
        files << AppFile.new(self, relative_file_name)
      end
      files
    end

    def file_exists?(path)
      File.exist?(file_path(path))
    end

    def read_file(path)
      File.read(file_path(path))
    end

    def read_json(path, symbolize_names = true)
      file = read_file(path)
      unless file.nil?
        JSON.parse(read_file(path), symbolize_names: symbolize_names)
      end
    end
  end
end
