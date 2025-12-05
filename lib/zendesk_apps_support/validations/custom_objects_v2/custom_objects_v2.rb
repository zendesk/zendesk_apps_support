# frozen_string_literal: true

require_relative 'constants'
require_relative 'limits_validator'
require_relative 'schema_validator'
require_relative 'validation_helpers'

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      class << self
        include Constants
        include ValidationHelpers

        SETTING_PLACEHOLDER_REGEXP = /\{\{\s*setting\.([\w.-]+)\s*\}\}/

        def call(requirements)
          structural_errors = validate_overall_requirements_structure(requirements)
          return structural_errors if structural_errors.any?

          payload_size_errors = validate_payload_size(requirements)
          return payload_size_errors if payload_size_errors.any?

          limits_and_schema_errors = [
            validate_limits(requirements),
            validate_schema(requirements)
          ].flatten

          return limits_and_schema_errors if limits_and_schema_errors.any?

          setting_placeholder_errors = validate_setting_placeholders(requirements)
          return setting_placeholder_errors if setting_placeholder_errors.any?

          validate_object_references(requirements)
        end

        private

        def validate_payload_size(requirements)
          payload_size = requirements.to_json.bytesize
          return [] if payload_size <= MAX_PAYLOAD_SIZE_BYTES

          [ValidationError.new(:excessive_cov2_payload_size)]
        end

        def validate_setting_placeholders(requirements)
          requirements_json = requirements.to_json
          return [] unless requirements_json.match?(SETTING_PLACEHOLDER_REGEXP)

          [ValidationError.new(:setting_placeholders_not_allowed_in_cov2_requirements)]
        end

        def validate_overall_requirements_structure(requirements)
          errors = validate_structural_requirements(requirements)
          return errors unless errors.empty?

          objects = requirements[SCHEMA_KEYS[:objects]]
          object_fields = requirements[SCHEMA_KEYS[:object_fields]]
          object_triggers = requirements[SCHEMA_KEYS[:object_triggers]]

          if all_collections_empty?(objects, object_fields, object_triggers)
            return [ValidationError.new(:empty_cov2_requirements)]
          end

          [
            validate_collection_is_array(objects, :invalid_objects_structure_in_cov2_requirements_v2),
            validate_collection_is_array(object_fields, :invalid_object_fields_structure_in_cov2_requirements_v2),
            validate_collection_is_array(object_triggers, :invalid_object_triggers_structure_in_cov2_requirements_v2)
          ].flatten
        end

        def validate_structural_requirements(requirements)
          return [ValidationError.new(:invalid_cov2_requirements_structure_v2)] unless requirements.is_a?(Hash)
          return [ValidationError.new(:empty_cov2_requirements)] if requirements.empty?

          []
        end

        def validate_limits(requirements)
          LimitsValidator.validate(requirements)
        end

        def validate_schema(requirements)
          SchemaValidator.validate(requirements)
        end

        def validate_object_references(requirements)
          valid_object_keys = extract_valid_object_keys(requirements[SCHEMA_KEYS[:objects]])

          REFERENCE_VALIDATION_CONFIG.flat_map do |collection_type, config|
            collection = requirements[collection_type]
            validate_collection_references(collection, valid_object_keys, config[:error], config[:identifier])
          end
        end

        def validate_collection_references(collection, valid_object_keys, error, identifier)
          valid_collection = extract_hash_entries(collection)
          valid_collection.filter_map do |item|
            object_key = item[OBJECT_KEY]
            next if valid_object_keys.include?(object_key)

            ValidationError.new(error,
                                item_identifier: safe_value(item[identifier]),
                                object_key: object_key)
          end
        end

        def validate_collection_is_array(collection, error_type)
          return [] if collection.nil? || collection.is_a?(Array)

          [ValidationError.new(error_type)]
        end

        def all_collections_empty?(objects, object_fields, object_triggers)
          [objects, object_fields, object_triggers].all? do |collection|
            collection.is_a?(Array) && collection.empty?
          end
        end

        def extract_valid_object_keys(objects)
          valid_objects = extract_hash_entries(objects)
          valid_objects.filter_map do |obj|
            key = obj[KEY]
            key if key.is_a?(String) && !key.strip.empty?
          end.uniq
        end
      end
    end
  end
end
