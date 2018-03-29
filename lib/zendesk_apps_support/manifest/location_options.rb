# frozen_string_literal: true

module ZendeskAppsSupport
  class Manifest
    class LocationOptions
      RUBY_TO_JSON = {
        legacy: 'legacy',
        auto_load: 'autoLoad',
        auto_hide: 'autoHide',
        signed: 'signed',
        url: 'url'
      }.freeze

      attr_reader :location
      attr_reader(*RUBY_TO_JSON.keys)

      alias_method :signed?, :signed
      alias_method :legacy?, :legacy
      alias_method :auto_load?, :auto_load
      alias_method :auto_hide?, :auto_hide

      def initialize(location, options)
        @location = location

        RUBY_TO_JSON.each do |ruby, json|
          instance_variable_set(:"@#{ruby}", options[json])
        end
        @legacy ||= @url == ZendeskAppsSupport::Manifest::LEGACY_URI_STUB
        @auto_load = options.fetch('autoLoad', true)
        @auto_hide ||= false
        @signed ||= false
      end
    end
  end
end
