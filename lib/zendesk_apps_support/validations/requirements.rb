require 'json'
require 'json/stream'

module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000

      class <<self
        def call(package)
          requirements_file = package.files.find { |f| f.relative_path == 'requirements.json' }

          return [ValidationError.new(:missing_requirements)] unless requirements_file

          requirements_stream = requirements_file.read
          duplicates = non_unique_type_keys(requirements_stream)
          unless duplicates.empty?
            return [ValidationError.new(:duplicate_requirements, duplicate_keys: duplicates.join(', '), count: duplicates.length)]
          end

          requirements = JSON.load(requirements_stream)
          [].tap do |errors|
            errors << invalid_requirements_types(requirements)
            errors << excessive_requirements(requirements)
            errors << missing_required_fields(requirements)
            errors.flatten!
            errors.compact!
          end
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def missing_required_fields(requirements)
          [].tap do |errors|
            requirements.values.each do |requirement|
              requirement.each do |identifier, fields|
                next if fields.include? 'title'
                errors << ValidationError.new(:missing_required_fields, field: 'title', identifier: identifier)
              end
            end

            unless requirements['user_fields'].nil?
              requirements['user_fields'].each do |identifier, fields|
                next if fields.include? 'key'
                errors << ValidationError.new(:missing_required_fields, field: 'key', identifier: identifier)
              end
            end
          end
        end

        def excessive_requirements(requirements)
          requirement_count = requirements.values.map(&:values).flatten.size
          if requirement_count > MAX_REQUIREMENTS
            ValidationError.new(:excessive_requirements, max: MAX_REQUIREMENTS, count: requirement_count)
          end
        end

        def invalid_requirements_types(requirements)
          invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES

          unless invalid_types.empty?
            ValidationError.new(:invalid_requirements_types, invalid_types: invalid_types.join(', '), count: invalid_types.length)
          end
        end

        def non_unique_type_keys(requirements)
          keys = []
          duplicates = []
          parser = JSON::Stream::Parser.new do
            start_object { keys.push({}) }
            end_object { keys.pop }
            key { |k| duplicates.push(k) if keys.last.include? k; keys.last[k] = nil }
          end
          parser << requirements

          duplicates
        end
      end
    end
  end
end
