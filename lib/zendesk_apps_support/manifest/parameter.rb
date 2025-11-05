# frozen_string_literal: true

module ZendeskAppsSupport
  class Manifest
    class Parameter
      TYPES = %w[text password checkbox url number multiline hidden oauth].freeze
      ATTRIBUTES = %i[name type required secure default scopes].freeze
      attr_reader(*ATTRIBUTES)
      def default?
        @has_default
      end

      def initialize(p)
        @name = p['name']
        @type = p['type'] || 'text'
        @required = p['required'] || false
        @secure = p['secure'] || false
        @has_default = p.key? 'default'
        @default = p['default'] if @has_default
        @scopes = p['scopes']
      end
    end
  end
end
