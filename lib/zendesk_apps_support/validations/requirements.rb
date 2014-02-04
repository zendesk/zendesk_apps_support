require 'multi_json'

module ZendeskAppsSupport
  module Validations
    module Requirements

      class <<self
        def call(package)
          requirements = package.files.find { |f| f.relative_path == 'requirements.json' }

          errors = []

          if requirements && !valid_json?(requirements)
            errors << ValidationError.new(:requirements_not_json)
          end

          errors
        end


        private

        def valid_json? json
          MultiJson.load(json)
          return true
        rescue MultiJson::DecodeError
          return false
        end

      end
    end
  end
end
