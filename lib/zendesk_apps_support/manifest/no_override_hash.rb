# frozen_string_literal: true

module ZendeskAppsSupport
  class Manifest
    class OverrideError < StandardError
      attr_reader :key, :original, :attempted
      attr_accessor :message
      def initialize(key, original, attempted)
        @key = key
        @original = original
        @attempted = attempted
      end

      def message
        @message ||= begin
          translated_error_key = 'txt.apps.admin.error.app_build.duplicate_reference'
          translated_error = ZendeskAppsSupport::I18n.t(translated_error_key, key: key)

          # if the error contains the word `_legacy` in the second sentence, let's
          # only use the first one.
          if [original, attempted].any? { |val| val.is_a?(String) && val =~ /_legacy/ }
            return translated_error
          end
          translated_detail_key = 'txt.apps.admin.error.app_build.duplicate_reference_values'
          translated_detail = ZendeskAppsSupport::I18n.t(translated_detail_key,
                                                         original: original,
                                                         attempted: attempted)
          "#{translated_error} #{translated_detail}"
        end
      end
    end

    class NoOverrideHash < Hash
      class << self
        def [](array)
          new.tap do |hash|
            array.each do |key, value|
              hash[key] = value
            end
          end
        end
      end

      def []=(key, value)
        raise OverrideError.new(key, self[key], value) if key? key
        super
      end
    end
  end
end
