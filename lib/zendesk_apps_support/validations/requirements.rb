require 'multi_json'

module ZendeskAppsSupport
  module Validations
    module Requirements

      class <<self
        def call(package)
          requirements = package.files.find { |f| f.relative_path == 'requirements.json' }

          return [ValidationError.new(:missing_requirements)] unless requirements
        end

      end
    end
  end
end
