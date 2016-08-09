# frozen_string_literal: true
module ZendeskAppsSupport
  class Manifest
    class Parameter
      TYPES = %w(text password checkbox url number multiline hidden).freeze
      attr_reader :name, :type, :required, :secure
      def initialize(p)
        @name = p['name']
        @type = p['type'] || 'text'
        @required = p['required'] || false
        @secure = p['secure'] || false
      end
    end
  end
end
