# frozen_string_literal: true

require_relative 'validation_helpers'
require_relative 'constants'

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      class LimitsValidator
        class << self
          include ValidationHelpers
          include Constants
          def validate(requirements)
            [
              validate_objects_excessive_limit(requirements[SCHEMA_KEYS[:objects]]),
              validate_fields_excessive_limit(requirements[SCHEMA_KEYS[:object_fields]]),
              validate_triggers_excessive_limit(requirements[SCHEMA_KEYS[:object_triggers]])
            ].flatten
          end

          private

          def validate_objects_excessive_limit(objects)
            return [] if objects.nil? || objects.size <= MAX_OBJECTS

            [ValidationError.new(:excessive_custom_objects_v2_requirements,
                                 max: MAX_OBJECTS,
                                 count: objects.size)]
          end

          def validate_fields_excessive_limit(object_fields)
            valid_fields = extract_hash_entries(object_fields).reject do |field|
              field[OBJECT_KEY].to_s.empty?
            end

            [
              validate_fields_limit(valid_fields),
              validate_selection_field_limits(valid_fields),
              validate_field_options_limits(valid_fields),
              validate_relationship_filter_limits(valid_fields)
            ].flatten
          end

          def validate_fields_limit(object_fields)
            validation_context = { max_limit: MAX_FIELDS_PER_OBJECT,
                                   error: :excessive_custom_objects_v2_fields }
            validate_collection_limits(object_fields, **validation_context)
          end

          def validate_selection_field_limits(object_fields)
            SELECTION_FIELD_LIMITS.flat_map do |field_type, max_limit|
              filtered_fields = object_fields.select { |field| field[TYPE] == field_type }
              validate_field_type_limit(filtered_fields, field_type, max_limit)
            end
          end

          def validate_field_type_limit(object_fields, field_type, max_limit)
            validation_context = { max_limit: max_limit,
                                   error: :excessive_cov2_selection_fields_per_object,
                                   field_type: field_type }

            validate_collection_limits(object_fields, **validation_context)
          end

          def validate_field_options_limits(object_fields)
            SELECTION_FIELD_OPTIONS_LIMITS.flat_map do |field_type, max_limit|
              validate_options_limit(object_fields, field_type, max_limit)
            end
          end

          def validate_options_limit(object_fields, field_type, max_limit)
            fields_with_options = object_fields.select do |field|
              field[TYPE] == field_type && field[CF_OPTIONS]&.any?
            end

            fields_with_options.filter_map do |field|
              options = field[CF_OPTIONS]

              next if options.size <= max_limit

              ValidationError.new(:excessive_cov2_field_options,
                                  max: max_limit,
                                  count: options.size,
                                  field_key: field[KEY],
                                  object_key: field[OBJECT_KEY])
            end
          end

          def validate_relationship_filter_limits(object_fields)
            object_fields
              .select { |field| field[RELATIONSHIP_FILTER] }
              .flat_map { |field| validate_relationship_filter_conditions(field) }
          end

          def validate_relationship_filter_conditions(field)
            relationship_filter = field[RELATIONSHIP_FILTER]
            return [] unless relationship_filter

            total_conditions = count_conditions(relationship_filter)

            return [] unless total_conditions > MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT

            [ValidationError.new(:excessive_cov2_relationship_filter_conditions,
                                 max: MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT,
                                 count: total_conditions,
                                 field_key: field[KEY],
                                 object_key: field[OBJECT_KEY])]
          end

          def validate_triggers_excessive_limit(object_triggers = [])
            valid_triggers = extract_hash_entries(object_triggers).reject do |trigger|
              trigger[OBJECT_KEY].to_s.empty?
            end
            return [] unless valid_triggers&.any?

            [
              validate_triggers_limit(valid_triggers),
              validate_triggers_conditions_limit(valid_triggers),
              validate_triggers_actions_limit(valid_triggers)
            ].flatten
          end

          def validate_triggers_limit(object_triggers)
            validation_context = { max_limit: MAX_TRIGGERS_PER_OBJECT,
                                   error: :excessive_custom_objects_v2_triggers }

            validate_collection_limits(object_triggers, **validation_context)
          end

          def validate_triggers_conditions_limit(object_triggers)
            object_triggers.flat_map do |trigger|
              validate_trigger_conditions(trigger)
            end
          end

          def validate_trigger_conditions(trigger)
            return [] unless trigger[CONDITIONS].is_a?(Hash)

            total_conditions = count_conditions(trigger[CONDITIONS])

            return [] unless total_conditions > MAX_CONDITIONS_PER_TRIGGER

            [ValidationError.new(:excessive_custom_objects_v2_trigger_conditions_v2,
                                 max: MAX_CONDITIONS_PER_TRIGGER,
                                 count: total_conditions,
                                 trigger_key: trigger[KEY])]
          end

          def validate_triggers_actions_limit(object_triggers)
            object_triggers.filter_map do |trigger|
              next unless trigger[ACTIONS]

              actions = trigger[ACTIONS]
              next if actions.size <= MAX_ACTIONS_PER_TRIGGER

              ValidationError.new(:excessive_custom_objects_v2_trigger_actions_v2,
                                  max: MAX_ACTIONS_PER_TRIGGER,
                                  count: actions.size,
                                  trigger_key: trigger[KEY])
            end
          end

          def validate_collection_limits(collection, **context)
            grouped_items = collection.group_by { |item| item[OBJECT_KEY] }

            grouped_items.filter_map do |object_key, items|
              next if items.size <= context[:max_limit]

              extra_context = context.except(:max_limit, :error)
              validation_context = {
                max: context[:max_limit],
                count: items.size,
                object_key: object_key,
                **extra_context
              }
              ValidationError.new(context[:error], validation_context)
            end
          end
        end
      end
    end
  end
end
