# frozen_string_literal: true

require 'build_errors_abstract'

module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000
      MAX_CUSTOM_OBJECTS_REQUIREMENTS = 50

      class << self
        def call(package)
          unless package.has_requirements?
            return [ValidationError.new(:missing_requirements)] if package.manifest.requirements_only?

            return []
          end

          return [ValidationError.new(:requirements_not_supported)] unless supports_requirements(package)

          begin
            requirements = package.requirements_json
          rescue ZendeskAppsSupport::Manifest::OverrideError => e
            return [ValidationError.new(:duplicate_requirements, duplicate_keys: e.key, count: 1)]
          end

          build_errors(requirements)
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def supports_requirements(package)
          !package.manifest.marketing_only? && package.manifest.products_ignore_locations != [Product::CHAT]
        end

        def validate_webhook_keys(identifier, requirement)
          required_keys = %w[name status endpoint http_method request_format]

          missing_keys = required_keys - requirement.keys

          missing_keys.map do |key|
            ValidationError.new(:missing_required_fields,
                                field: key,
                                identifier: identifier)
          end
        end

        def validate_custom_objects_keys(keys, expected_keys, identifier, errors = [])
          missing_keys = expected_keys - keys
          missing_keys.each do |key|
            errors << ValidationError.new(:missing_required_fields,
                                          field: key,
                                          identifier: identifier)
          end
        end

        def build_errors(requirements)
          [].tap do |errors|
            BuildErrors.build_errors(requirements, self).each { |error| errors << error }
            errors.flatten!
            errors.compact!
          end
        end
      end
    end
  end
end
