# frozen_string_literal: true

require_relative 'custom_objects_v2/constants'
require_relative 'custom_objects_v2/schema_validator'
require_relative 'custom_objects_v2/limits_validator'

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      include Constants
      class << self
        def call(requirements)
          errors = validate_overall_requirements_structure(requirements)
          return errors if errors.any?

          payload_size_errors = validate_payload_size(requirements)
          return payload_size_errors if payload_size_errors.any?

          [
            validate_limits(requirements),
            validate_schema(requirements)
          ].flatten
        end

        private

        def validate_payload_size(requirements)
          payload_size = requirements.to_json.bytesize
          return [] if payload_size <= MAX_PAYLOAD_SIZE_BYTES

          [ValidationError.new(:excessive_cov2_payload_size)]
        end

        def validate_overall_requirements_structure(requirements)
          errors = validate_structural_requirements(requirements)
          return errors unless errors.empty?

          objects = requirements[SCHEMA_KEYS[:objects]]
          object_fields = requirements[SCHEMA_KEYS[:object_fields]]
          object_triggers = requirements[SCHEMA_KEYS[:object_triggers]]

          if all_collections_empty_or_nil?(objects, object_fields, object_triggers)
            return [ValidationError.new(:empty_cov2_requirements)]
          end

          [
            validate_collection_is_array(objects, :invalid_objects_structure_in_cov2_requirements),
            validate_collection_is_array(object_fields, :invalid_object_fields_structure_in_cov2_requirements),
            validate_collection_is_array(object_triggers, :invalid_object_triggers_structure_in_cov2_requirements)
          ].flatten
        end

        def validate_structural_requirements(requirements)
          return [ValidationError.new(:invalid_cov2_requirements_structure)] unless requirements.is_a?(Hash)
          return [ValidationError.new(:empty_cov2_requirements)] if requirements.empty?

          []
        end

        def validate_limits(requirements)
          LimitsValidator.validate(requirements)
        end

        def validate_schema(requirements)
          SchemaValidator.validate(requirements)
        end

        def validate_collection_is_array(collection, error_type)
          return [] if collection.nil? || collection.is_a?(Array)

          [ValidationError.new(error_type)]
        end

        def all_collections_empty_or_nil?(objects, object_fields, object_triggers)
          [objects, object_fields, object_triggers].all? do |collection|
            collection.nil? || (collection.is_a?(Array) && collection.empty?)
          end
        end
      end
    end
  end
end
