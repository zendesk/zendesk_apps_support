# frozen_string_literal: true
require 'sass'
require 'sassc'
require 'zendesk_apps_support/sass_functions'

module ZendeskAppsSupport
  class StylesheetCompiler
    def initialize(source, app_id, url_prefix)
      @source = source
      @app_id = app_id
      @url_prefix = url_prefix
    end

    def compile(sassc: false)
      options = {
        syntax: :scss, app_asset_url_builder: self
      }
      if sassc
        compiler_class = SassC
        options[:style] = :compressed
      else
        compiler_class = Sass
      end
      compiler_class::Engine.new(wrapped_source.dup, options).render
    end

    def app_asset_url(name)
      "#{@url_prefix}#{name}"
    end

    private

    def wrapped_source
      ".app-#{@app_id} {#{@source}}"
    end
  end
end
