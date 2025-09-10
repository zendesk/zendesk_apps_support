# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      class SchemaValidator
        include Constants

        class << self
          def validate(requirements)
            [
              validate_objects_schema(requirements[SCHEMA_KEYS[:objects]]),
              validate_fields_schema(requirements[SCHEMA_KEYS[:object_fields]]),
              validate_triggers_schema(requirements[SCHEMA_KEYS[:object_triggers]])
            ].flatten
          end

          private

          # ========== SCHEMA VALIDATION ==========

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
            required_keys = %w[object_key title actions conditions]
            missing_keys = required_keys - trigger.keys
            trigger_title = safe_value(trigger[TITLE])
            object_key = safe_value(trigger[OBJECT_KEY])

            errors = missing_keys.map do |missing_key|
              ValidationError.new(:missing_cov2_trigger_schema_key,
                                  missing_key: missing_key,
                                  trigger_title: trigger_title,
                                  object_key: object_key)
            end

            errors.concat(validate_conditions_schema(trigger[CONDITIONS], object_key, trigger_title))
            errors.concat(validate_actions_schema(trigger[ACTIONS], object_key, trigger_title))
            errors
          end

          def validate_conditions_schema(conditions, object_key, title)
            error_data = { trigger_title: title, object_key: object_key }

            unless valid_conditions_structure?(conditions)
              return [ValidationError.new(:invalid_cov2_trigger_conditions_structure, **error_data)]
            end

            if count_conditions(conditions).zero?
              return [ValidationError.new(:empty_cov2_trigger_conditions, **error_data)]
            end

            []
          end

          def validate_actions_schema(actions, object_key, title)
            error_data = { trigger_title: title, object_key: object_key }

            unless actions.is_a?(Array)
              return [ValidationError.new(:invalid_cov2_trigger_actions_structure, **error_data)]
            end

            return [] unless actions.empty?

            [ValidationError.new(:empty_cov2_trigger_actions, **error_data)]
          end

          # ========== SHARED HELPER METHODS ==========

          def extract_hash_entries(collection)
            return [] unless collection&.any?

            collection.select { |item| item.is_a?(Hash) }
          end

          def safe_value(value)
            value || UNDEFINED_VALUE
          end

          def count_conditions(conditions)
            return 0 unless conditions.is_a?(Hash)

            CONDITION_KEYS.sum { |key| conditions[key]&.size || 0 }
          end

          def valid_conditions_structure?(conditions)
            return false unless conditions.is_a?(Hash)

            (conditions.key?(ALL) || conditions.key?(ANY)) &&
              CONDITION_KEYS.all? { |key| conditions[key].nil? || conditions[key].is_a?(Array) }
          end
        end
      end
    end
  end
end
