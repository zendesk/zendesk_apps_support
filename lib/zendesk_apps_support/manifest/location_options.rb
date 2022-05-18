# frozen_string_literal: true

module ZendeskAppsSupport
  class Manifest
    class LocationOptions
      RUBY_TO_JSON = {
        legacy: 'legacy',
        auto_load: 'autoLoad',
        auto_hide: 'autoHide',
        flexible: 'flexible',
        signed: 'signed',
        url: 'url',
        size: 'size'
      }.freeze

      attr_reader :location, *RUBY_TO_JSON.keys

      alias signed? signed
      alias legacy? legacy
      alias auto_load? auto_load
      alias auto_hide? auto_hide

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
