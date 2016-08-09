# frozen_string_literal: true
require 'json'

module ZendeskAppsSupport
  class Manifest
    class OverrideError < StandardError
      class << self
        def message_for(key, original = nil, attempted = nil)
          message = "Duplicate reference in manifest: #{key}"
          if original && attempted
            message = "#{message}. Initially set to #{original}, attempted overwrite to #{attempted}."
          end
          message
        end
      end
    end

    class NoOverrideHash < Hash
      class << self
        def [](array)
          uniques = Set.new
          array.each do |key, _value|
            if uniques.add?(key).nil?
              # don't add the value to the error message because it might be '_legacy'
              raise OverrideError, OverrideError.message_for(key)
            end
          end
          super
        end
      end

      def []=(key, value)
        raise OverrideError, OverrideError.message_for(key, self[key], value) if key? key
        super
      end
    end
  end
end
