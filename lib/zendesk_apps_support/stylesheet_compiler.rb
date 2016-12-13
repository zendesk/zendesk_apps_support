# frozen_string_literal: true
require 'sassc'
require 'zendesk_apps_support/sass_functions'

module ZendeskAppsSupport
  class StylesheetCompiler
    def initialize(source, app_id, url_prefix)
      @source = source
      @app_id = app_id
      @url_prefix = url_prefix
    end

    def compile
      SassC::Engine.new(wrapped_source.dup, syntax: :scss, style: :compressed, app_asset_url_builder: self).render
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
