# frozen_string_literal: true

require_relative 'validation_helpers'
require_relative 'constants'

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      class SchemaValidator
        class << self
          include ValidationHelpers
          include Constants

          def validate(requirements)
            schema_errors = validate_schema_keys(requirements)
            return schema_errors if schema_errors.any?

            validate_setting_placeholder_values(requirements)
          end

          private

          def validate_schema_keys(requirements)
            [
              validate_objects_schema(requirements[SCHEMA_KEYS[:objects]]),
              validate_fields_schema(requirements[SCHEMA_KEYS[:object_fields]]),
              validate_triggers_schema(requirements[SCHEMA_KEYS[:object_triggers]])
            ].flatten
          end

          def validate_setting_placeholder_values(requirements)
            [
              validate_objects_placeholder_values(requirements[SCHEMA_KEYS[:objects]]),
              validate_fields_placeholder_values(requirements[SCHEMA_KEYS[:object_fields]]),
              validate_triggers_placeholder_values(requirements[SCHEMA_KEYS[:object_triggers]])
            ].flatten
          end

          def validate_objects_schema(objects = [])
            valid_objects = extract_hash_entries(objects)
            valid_objects.flat_map { |object| validate_object_schema(object) }
          end

          def validate_object_schema(object)
            required_keys = %w[key title title_pluralized include_in_list_view]
            missing_keys = required_keys - object.keys

            missing_keys.map do |missing_key|
              ValidationError.new(:missing_cov2_object_schema_key,
                                  missing_key: missing_key,
                                  object_key: safe_value(object[KEY]))
            end
          end

          def validate_fields_schema(object_fields = [])
            valid_fields = extract_hash_entries(object_fields)
            valid_fields.flat_map { |field| validate_field_schema(field) }
          end

          def validate_field_schema(field)
            required_keys = %w[key title type object_key]
            missing_keys = required_keys - field.keys

            missing_keys.map do |missing_key|
              ValidationError.new(:missing_cov2_field_schema_key,
                                  missing_key: missing_key,
                                  field_key: safe_value(field[KEY]),
                                  object_key: safe_value(field[OBJECT_KEY]))
            end
          end

          def validate_triggers_schema(object_triggers = [])
            valid_triggers = extract_hash_entries(object_triggers)
            valid_triggers.flat_map { |trigger| validate_trigger_schema(trigger) }
          end

          def validate_trigger_schema(trigger)
            required_keys = %w[key object_key title actions conditions]
            missing_keys = required_keys - trigger.keys
            trigger_key = safe_value(trigger[KEY])
            object_key = safe_value(trigger[OBJECT_KEY])

            errors = missing_keys.map do |missing_key|
              ValidationError.new(:missing_cov2_trigger_schema_key_v2,
                                  missing_key: missing_key,
                                  trigger_key: trigger_key,
                                  object_key: object_key)
            end

            errors.concat(validate_conditions_schema(trigger[CONDITIONS], object_key, trigger_key))
            errors.concat(validate_actions_schema(trigger[ACTIONS], object_key, trigger_key))
            errors
          end

          def validate_conditions_schema(conditions, object_key, trigger_key)
            error_data = { trigger_key:, object_key: }

            unless valid_conditions_structure?(conditions)
              return [ValidationError.new(:invalid_cov2_trigger_conditions_structure_v2, **error_data)]
            end

            if count_conditions(conditions).zero?
              return [ValidationError.new(:empty_cov2_trigger_conditions_v2, **error_data)]
            end

            []
          end

          def validate_actions_schema(actions, object_key, trigger_key)
            error_data = { trigger_key:, object_key: }

            unless actions.is_a?(Array)
              return [ValidationError.new(:invalid_cov2_trigger_actions_structure_v2,
                                          **error_data)]
            end

            return [] unless actions.empty?

            [ValidationError.new(:empty_cov2_trigger_actions_v2, **error_data)]
          end

          def valid_conditions_structure?(conditions)
            return false unless conditions.is_a?(Hash) && conditions.any?
            return false if (conditions.keys - CONDITION_KEYS).any?

            conditions.values.any? { |v| v.is_a?(Array) }
          end

          def validate_objects_placeholder_values(objects)
            valid_objects = extract_hash_entries(objects)
            valid_objects.flat_map do |object|
              validate_object_placeholder_values(object, object[KEY])
            end
          end

          def validate_object_placeholder_values(object, object_identifier)
            object.select { |_, value| contains_setting_placeholder?(value) }.map do |property_name, property_value|
              ValidationError.new(
                :cov2_object_setting_placeholder_not_allowed,
                object_key: safe_value(object_identifier),
                property_name:,
                property_value:
              )
            end
          end

          def validate_fields_placeholder_values(object_fields)
            valid_fields = extract_hash_entries(object_fields)
            valid_fields.flat_map do |field|
              validate_field_placeholder_values(field, field[KEY], field[OBJECT_KEY])
            end
          end

          def validate_field_placeholder_values(field, field_identifier, object_identifier)
            field.select { |_, value| contains_setting_placeholder?(value) }.map do |property_name, property_value|
              ValidationError.new(
                :cov2_field_setting_placeholder_not_allowed,
                field_key: safe_value(field_identifier),
                object_key: safe_value(object_identifier),
                property_name:,
                property_value:
              )
            end
          end

          def validate_triggers_placeholder_values(object_triggers)
            valid_triggers = extract_hash_entries(object_triggers)
            valid_triggers.flat_map do |trigger|
              validate_trigger_placeholder_values(trigger, trigger[KEY], trigger[OBJECT_KEY])
            end
          end

          def validate_trigger_placeholder_values(trigger, trigger_identifier, object_identifier)
            keys_to_check = %w[key object_key title]

            keys_to_check.filter_map do |key|
              value = trigger[key]
              next unless value.is_a?(String) && contains_setting_placeholder?(value)

              ValidationError.new(
                :cov2_trigger_setting_placeholder_not_allowed,
                trigger_key: safe_value(trigger_identifier),
                object_key: safe_value(object_identifier),
                property_name: key,
                property_value: value
              )
            end
          end
        end
      end
    end
  end
end
