module ZendeskAppsSupport
  module Validations

    class ValidationError
      attr_reader :key, :data
      
      def initialize(key, data = nil)
        @key, @data = key, data || {}
      end

      def to_s
        ZendeskAppsSupport::I18n.t(key.to_s, data)
      end
    end

    class JSHintValidationError < ValidationError
      attr_reader :filename, :jshint_errors

      def initialize(filename, jshint_errors)
        errors = jshint_errors.map { |err| "\n  L#{err['line']}: #{err['reason']}" }.join('')
        @filename = filename, @jshint_errors = jshint_errors
        super('txt.apps.admin.error.app_build.jshint_error', {
          :file => filename,
          :errors => errors,
          :count => jshint_errors.length
        })
      end
    end
  end
end
