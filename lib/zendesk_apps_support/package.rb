require 'pathname'
require 'erubis'
require 'json'

module ZendeskAppsSupport
  class Package
    include ZendeskAppsSupport::BuildTranslation

    DEFAULT_LAYOUT = Erubis::Eruby.new(File.read(File.expand_path('../assets/default_template.html.erb', __FILE__)))
    DEFAULT_SCSS   = File.read(File.expand_path('../assets/default_styles.scss', __FILE__))
    SRC_TEMPLATE   = Erubis::Eruby.new(File.read(File.expand_path('../assets/src.js.erb', __FILE__)))
    TEMPLATES      = Erubis::Eruby.new(File.read(File.expand_path('../assets/templates.js.erb', __FILE__)))

    attr_reader :lib_root, :root, :warnings
    attr_accessor :requirements_only

    def initialize(dir)
      @root = Pathname.new(File.expand_path(dir))
      @lib_root = Pathname.new(File.join(@root, 'lib'))
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

    def app_js
      read_file('app.js')
    end

    def commonjs_modules
      return unless has_lib_js?

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

    def translation_files
      files.select { |f| f =~ /^translations\// }
    end

    def manifest_json
      read_json('manifest.json')
    end

    def requirements_json
      read_json('requirements.json')
    end

    def translations(locale)
      file_path = "translations/#{locale}.json"
      file_path = "translations/en.json" unless file_exists?(file_path)
      read_json(file_path, false)
    end

    def app_translations(locale)
      remove_zendesk_keys(translations(locale))
    end

    def readified_js(app_name, app_id, asset_url_prefix, settings = {}, locale = 'en')
      manifest = manifest_json
      source = app_js
      name = app_name || manifest[:name] || 'Local App'
      location = manifest[:location]
      app_class_name = "app-#{app_id}"
      author = manifest[:author]
      framework_version = manifest[:frameworkVersion]
      single_install = manifest[:singleInstall] || false
      no_template = manifest[:noTemplate]
      templates = no_template ? {} : compiled_templates(app_id, asset_url_prefix)

      settings['title'] = name

      app_settings = {
        location: location,
        noTemplate: no_template,
        singleInstall: single_install
      }.select { |_k, v| !v.nil? }

      templates = TEMPLATES.result(templates: templates) unless no_template

      SRC_TEMPLATE.result(
          name: name,
          source: source,
          app_settings: app_settings,
          asset_url_prefix: asset_url_prefix,
          app_class_name: app_class_name,
          author: author,
          translations: app_translations(locale),
          framework_version: framework_version,
          templates: templates,
          settings: settings,
          app_id: app_id,
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

    private

    def compiled_templates(app_id, asset_url_prefix)
      compiled_css = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + customer_css, app_id, asset_url_prefix).compile

      templates = begin
        Dir["#{root}/templates/*.hdbs"].inject({}) do |h, file|
          str = File.read(file)
          str.chomp!
          name = template_name(file)
          # layout will be precompiled later with css
          str = precompile_handlebars(str) unless name == "layout"
          h[name] = str
          h
        end
      end

      layout = templates['layout'] || DEFAULT_LAYOUT.result

      templates.tap do |templates|
        templates['layout'] = precompile_handlebars("<style>\n#{compiled_css}</style>\n#{layout}")
      end
    end

    def template_name(file)
      File.basename(file, File.extname(file))
    end

    def precompile_handlebars(template)
      @jscontext ||= begin
        require 'execjs'
        handlebars_js = File.read(File.expand_path('../assets/handlebars.js', __FILE__))
        ExecJS.compile(handlebars_js)
      end
      @jscontext.call("Handlebars.precompile", template)
    end

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
