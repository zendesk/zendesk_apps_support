# frozen_string_literal: true
module ZendeskAppsSupport
  class LocationOptions
    RUBY_TO_JSON = {
      legacy: 'legacy',
      auto_load: 'autoLoad',
      auto_hide: 'autoHide',
      url: 'url'
    }.freeze

    attr_reader :location
    attr_reader(*RUBY_TO_JSON.keys)

    def initialize(location, options)
      @location = location

      RUBY_TO_JSON.each do |ruby, json|
        instance_variable_set(:"@#{ruby}", options[json])
      end
      @legacy ||= @uri == ZendeskAppsSupport::Manifest::LEGACY_URI_STUB
      @auto_load = options.fetch('autoLoad', true)
      @auto_hide ||= false
    end
  end
end
