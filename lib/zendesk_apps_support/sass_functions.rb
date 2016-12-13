# frozen_string_literal: true
require 'sassc'

module SassC::Script::Functions
  module AppAssetUrl
    def app_asset_url(name)
      raise ArgumentError, "Expected #{name} to be a string" unless name.is_a? Sass::Script::Value::String
      result = %{url("#{app_asset_url_helper(name)}")}
      SassC::Script::String.new(result)
    end

    private

    def app_asset_url_helper(name)
      url_builder = options[:app_asset_url_builder]
      url_builder.app_asset_url(name.value)
    end
  end

  include AppAssetUrl
end
