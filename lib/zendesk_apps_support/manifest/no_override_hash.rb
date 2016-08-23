# frozen_string_literal: true
require 'json'

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
        @message ||= "Duplicate reference in manifest: #{key}."\
        " Initially set to #{original}, attempted overwrite to #{attempted}."
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
