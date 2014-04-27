require 'pathname'
require 'erubis'
require 'json'

module ZendeskAppsSupport
  class Package
    include ZendeskAppsSupport::BuildTranslation

    DEFAULT_LAYOUT = Erubis::Eruby.new( File.read(File.expand_path('../assets/default_template.html.erb', __FILE__)) )
    DEFAULT_SCSS   = File.read(File.expand_path('../assets/default_styles.scss', __FILE__))
    SRC_TEMPLATE   = Erubis::Eruby.new( File.read(File.expand_path('../assets/src.js.erb', __FILE__)) )
    INSTALLED_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installed.js.erb', __FILE__)) )

    attr_reader :root, :warnings
    attr_accessor :requirements_only

    def initialize(dir)
      @root = Pathname.new(File.expand_path(dir))
      @warnings = []
      @apps = []
      @requirements_only = false
    end

    def change_dir(dir)
      @root = Pathname.new(File.expand_path(dir))
      self
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

    def files
      non_tmp_files
    end

    def template_files
      files.select { |f| f =~ /^templates\/.*\.hdbs$/ }
    end

    def translation_files
      files.select { |f| f =~ /^translations\// }
    end

    def manifest_json
      read_json("manifest.json")
    end

    def requirements_json
      read_json("requirements.json")
    end

    def translations
      read_json("translations/en.json", false)
    end

    def app_translations
      remove_zendesk_keys(translations)
    end

    def readified_js(app_name, app_id, asset_url_prefix, settings={})
      manifest = manifest_json
      source = read_file("app.js")
      name = app_name || manifest[:name] || 'Local App'
      location = manifest[:location]
      app_class_name = "app-#{app_id}"
      author = manifest[:author]
      framework_version = manifest[:frameworkVersion]
      templates = manifest[:noTemplate] ? {} : compiled_templates(app_id, asset_url_prefix)

      settings["title"] = name

      @apps << SRC_TEMPLATE.result(
          :name => name,
          :source => source,
          :location => location,
          :asset_url_prefix => asset_url_prefix,
          :app_class_name => app_class_name,
          :author => author,
          :translations => app_translations,
          :framework_version => framework_version,
          :templates => templates,
          :settings => settings,
          :app_id => app_id
      )
    end

    def get_installed()
      INSTALLED_TEMPLATE.result(
          :apps => @apps
      )
    end

    def customer_css
      css_file = file_path('app.css')
      customer_css = File.exist?(css_file) ? File.read(css_file) : ""
    end

    def has_js?
      file_exists?("app.js")
    end

    def has_manifest?
      file_exists?("manifest.json")
    end

    def has_location?
      manifest_json[:location]
    end

    def has_requirements?
      file_exists?("requirements.json")
    end

    def has_banner?
      file_exists?("assets/banner.png")
    end

    def file_path(path)
      File.join(root, path)
    end

    private

    def compiled_templates(app_id, asset_url_prefix)
      compiled_css = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + customer_css, app_id, asset_url_prefix).compile

      templates = begin
        Dir["#{root.to_s}/templates/*.hdbs"].inject({}) do |h, file|
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

    def non_tmp_files
      files = []
      Dir[ root.join('**/**') ].each do |f|
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
        JSON.parse(read_file(path), :symbolize_names => symbolize_names)
      end
    end
  end
end
