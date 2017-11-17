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

    LOCATIONS_WITH_ICONS = %w(top_bar nav_bar system_top_bar ticket_editor).freeze

    attr_reader :lib_root, :root, :warnings

    def initialize(dir, is_cached = true)
      @root     = Pathname.new(File.expand_path(dir))
      @lib_root = Pathname.new(File.join(root, 'lib'))

      @is_cached = is_cached # disabled by ZAT for development
      @warnings = []
    end

    def validate(marketplace: true)
      errors = []
      errors << Validations::Manifest.call(self)
      if has_valid_manifest?(errors)
        errors << Validations::Marketplace.call(self) if marketplace
        errors << Validations::Source.call(self)
        errors << Validations::Translations.call(self)
        errors << Validations::Requirements.call(self)

        unless manifest.requirements_only? || manifest.marketing_only? || manifest.iframe_only?
          errors << Validations::Templates.call(self)
          errors << Validations::Stylesheets.call(self)
        end
      end

      errors << Validations::Banner.call(self) if has_banner?
      errors << Validations::Svg.call(self) if has_svgs?

      errors.flatten.compact
    end

    def validate!(marketplace: true)
      errors = validate(marketplace: marketplace)
      raise errors.first if errors.any?
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
        relative_file_name = f.sub(%r{#{root}/?}, '')
        next if relative_file_name =~ %r{^tmp/}
        files << AppFile.new(self, relative_file_name)
      end
      files
    end

    def js_files
      @js_files ||= files.select { |f| f.to_s == 'app.js' || (f.to_s.start_with?('lib/') && f.to_s.end_with?('.js')) }
    end

    def lib_files
      @lib_files ||= js_files.select { |f| f =~ %r{^lib/} }
    end

    def svg_files
      @svg_files ||= files.select { |f| f =~ %r{^assets/.*\.svg$} }
    end

    def template_files
      files.select { |f| f =~ %r{^templates/.*\.hdbs$} }
    end

    def translation_files
      files.select { |f| f =~ %r{^translations/} }
    end

    # this is not really compile_js, it compiles the whole app including scss for v1 apps
    def compile(options)
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

      SRC_TEMPLATE.result(
        name: name,
        version: manifest.version,
        source: source,
        app_class_properties: manifest.app_class_properties,
        asset_url_prefix: asset_url_prefix,
        logo_asset_hash: generate_logo_hash(manifest.products),
        location_icons: location_icons,
        app_class_name: app_class_name,
        author: manifest.author,
        translations: runtime_translations(translations_for(locale)),
        framework_version: manifest.framework_version,
        templates: templates,
        modules: commonjs_modules,
        iframe_only: manifest.iframe_only?
      )
    end

    alias compile_js compile
    deprecate :compile_js, :compile, 2017, 1

    def manifest_json
      @manifest_json ||= read_json(MANIFEST_FILENAME)
    end
    deprecate :manifest_json, :manifest, 2016, 9

    def manifest
      @manifest ||= Manifest.new(read_file(MANIFEST_FILENAME))
    end

    def requirements_json
      return nil unless has_requirements?
      @requirements ||= read_json(REQUIREMENTS_FILENAME, object_class: Manifest::NoOverrideHash)
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
      compiler = ZendeskAppsSupport::StylesheetCompiler.new(DEFAULT_SCSS + app_css, app_id, asset_url_prefix)
      compiled_css = compiler.compile(sassc: manifest.enabled_experiments.include?('newCssCompiler'))

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

    def has_file?(path)
      File.file?(path_to(path))
    end

    def has_svgs?
      svg_files.any?
    end

    def has_requirements?
      has_file?(REQUIREMENTS_FILENAME)
    end

    def app_css
      return File.read(path_to('app.scss')) if has_file?('app.scss')
      return File.read(path_to('app.css')) if has_file?('app.css')
      ''
    end

    def app_js
      if @is_cached
        @app_js ||= read_file('app.js')
      else
        read_file('app.js')
      end
    end

    def iframe_only?
      manifest.iframe_only?
    end
    deprecate :iframe_only?, 'manifest.iframe_only?', 2016, 9

    def templates
      templates_dir = path_to('templates')
      Dir["#{templates_dir}/*.hdbs"].each_with_object({}) do |file, memo|
        str = File.read(file)
        str.chomp!
        memo[File.basename(file, File.extname(file))] = str
        memo
      end
    end

    def translations
      return @translations if @is_cached && @translations

      @translations = begin
        translation_dir = path_to('translations')
        return {} unless File.directory?(translation_dir)

        locale_path = "#{translation_dir}/#{manifest.default_locale}.json"
        default_translations = process_translations(locale_path, default_locale: true)

        Dir["#{translation_dir}/*.json"].each_with_object({}) do |path, memo|
          locale = File.basename(path, File.extname(path))

          locale_translations = if locale == manifest.default_locale
                                  default_translations
                                else
                                  deep_merge_hash(default_translations, process_translations(path))
                                end

          memo[locale] = locale_translations
        end
      end
    end

    private

    def generate_logo_hash(products)
      {}.tap do |logo_hash|
        products.each do |product|
          product_prefix = products.count > 1 ? "#{product.name.downcase}/" : ''
          logo_hash[product.name.downcase] = "#{product_prefix}logo-small.png"
        end
      end
    end

    def has_valid_manifest?(errors)
      has_manifest? && errors.flatten.empty?
    end

    def runtime_translations(translations)
      result = translations.dup
      result.delete('name')
      result.delete('short_description')
      result.delete('long_description')
      result.delete('installation_instructions')
      result
    end

    def process_translations(locale_path, default_locale: false)
      translations = File.exist?(locale_path) ? JSON.parse(File.read(locale_path)) : {}
      translations['app'].delete('name') if !default_locale && translations.key?('app')
      translations['app'].delete('package') if translations.key?('app')
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

    def location_icons
      Hash.new { |h, k| h[k] = {} }.tap do |location_icons|
        manifest.location_options.each do |location_options|
          next unless location_options.location &&
                      LOCATIONS_WITH_ICONS.include?(location_options.location.name) &&
                      location_options.location.product == Product::SUPPORT

          host = location_options.location.product.name
          location = location_options.location.name
          product_prefix = manifest.products.count > 1 ? "#{host}/" : ''
          location_icons[host][location] = build_location_icons_hash(location, product_prefix)
        end
      end
    end

    def build_location_icons_hash(location, product_prefix)
      inactive_png = "icon_#{location}_inactive.png"
      if has_file?("assets/#{product_prefix}icon_#{location}.svg")
        build_svg_icon_hash(location, product_prefix)
      elsif has_file?("assets/#{product_prefix}#{inactive_png}")
        build_png_icons_hash(location, product_prefix)
      else
        {}
      end
    end

    def build_svg_icon_hash(location, product_prefix)
      cache_busting_param = "?#{Time.now.to_i}" unless @is_cached
      { 'svg' => "#{product_prefix}icon_#{location}.svg#{cache_busting_param}" }
    end

    def build_png_icons_hash(location, product_prefix)
      inactive_png = "#{product_prefix}icon_#{location}_inactive.png"
      {
        'inactive' => inactive_png
      }.tap do |icon_state_hash|
        %w(active hover).each do |state|
          specific_png = "#{product_prefix}icon_#{location}_#{state}.png"
          selected_png = has_file?("assets/#{specific_png}") ? specific_png : inactive_png
          icon_state_hash[state] = selected_png
        end
      end
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
        result_h[key] = if h.key?(key) && h[key].is_a?(Hash) && value.is_a?(Hash)
                          deep_merge_hash(h[key], value)
                        else
                          value
                        end
      end
      result_h
    end

    def read_file(path)
      File.read(path_to(path))
    end

    def read_json(path, parser_opts = {})
      file = read_file(path)
      JSON.parse(read_file(path), parser_opts) unless file.nil?
    end
  end
end
