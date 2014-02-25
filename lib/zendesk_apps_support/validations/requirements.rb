require 'multi_json'
require 'json/stream'
require 'pp'

module ZendeskAppsSupport
  module Validations
    module Requirements

      class <<self
        def call(package)
          requirements_file = package.files.find { |f| f.relative_path == 'requirements.json' }

          return [ValidationError.new(:missing_requirements)] unless requirements_file

          requirements_stream = requirements_file.read
          duplicates = non_unique_type_keys(requirements_stream)
          unless duplicates.empty?
            return [ValidationError.new(:duplicate_requirements, :duplicate_keys => duplicates.join(', '), :count => duplicates.length)]
          end

          requirements = MultiJson.load(requirements_stream)
          [].tap do |errors|
            errors << invalid_requirements_types(requirements)
            errors.compact!
          end
        rescue MultiJson::DecodeError => e
          return [ValidationError.new(:requirements_not_json, :errors => e)]
        end

        private

        def invalid_requirements_types(requirements)
          invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES

          unless invalid_types.empty?
            ValidationError.new(:invalid_requirements_types, :invalid_types => invalid_types.join(', '), :count => invalid_types.length)
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
