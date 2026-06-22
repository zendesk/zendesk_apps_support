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
        size: 'size',
        object_types: 'objectTypes'
      }.freeze

      OBJECT_TYPES_LOCATION = 'cov2_records_sidebar'

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
        @object_types = nil unless @location&.name == OBJECT_TYPES_LOCATION
      end
    end
  end
end
