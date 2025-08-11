# rubocop:disable Metrics/ModuleLength
# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      MAX_OBJECTS = 50
      MAX_FIELDS_PER_OBJECT = 10
      MAX_TRIGGERS_PER_OBJECT = 100
      MAX_CONDITIONS_PER_TRIGGER = 50
      MAX_ACTIONS_PER_TRIGGER = 25
      MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT = 20
      MAX_DROPDOWN_FIELDS_PER_OBJECT = 5
      MAX_MULTISELECT_FIELDS_PER_OBJECT = 5
      MAX_DROPDOWN_OPTIONS_PER_FIELD = 10
      MAX_MULTISELECT_OPTIONS_PER_FIELD = 10

      SELECTION_FIELD_LIMITS = {
        'dropdown' => MAX_DROPDOWN_FIELDS_PER_OBJECT,
        'multiselect' => MAX_MULTISELECT_FIELDS_PER_OBJECT
      }.freeze

      SELECTION_FIELD_OPTIONS_LIMITS = {
        'dropdown' => MAX_DROPDOWN_OPTIONS_PER_FIELD,
        'multiselect' => MAX_MULTISELECT_OPTIONS_PER_FIELD
      }.freeze

      class << self
        def call(requirements)
          custom_objects_v2_requirements = requirements[AppRequirement::CUSTOM_OBJECTS_V2_KEY]
          return [] unless custom_objects_v2_requirements

          [
            validate_limits(custom_objects_v2_requirements),
            validate_schema(custom_objects_v2_requirements)
          ].flatten
        end

        private

        def validate_limits(custom_objects_v2_requirements)
          [
            validate_objects_excessive_limit(custom_objects_v2_requirements),
            validate_fields_excessive_limit(custom_objects_v2_requirements),
            validate_triggers_excessive_limit(custom_objects_v2_requirements)
          ].flatten
        end

        def validate_schema(custom_objects_v2_requirements)
          [
            validate_objects_schema(custom_objects_v2_requirements),
            validate_fields_schema(custom_objects_v2_requirements),
            validate_triggers_schema(custom_objects_v2_requirements)
          ].flatten
        end

        # ========== OBJECTS VALIDATION ==========

        def validate_objects_excessive_limit(custom_objects_v2_requirements)
          objects = custom_objects_v2_requirements['objects']
          return [] unless objects

          return [] unless objects.size > MAX_OBJECTS

          [ValidationError.new(:excessive_custom_objects_v2_requirements,
                               max: MAX_OBJECTS,
                               count: objects.size)]
        end

        # ========== FIELDS VALIDATION ==========

        def validate_fields_excessive_limit(custom_objects_v2_requirements)
          object_fields = custom_objects_v2_requirements['object_fields']
          [
            validate_fields_limit(object_fields),
            validate_selection_field_limits(object_fields),
            validate_selection_field_options_limits(object_fields),
            validate_conditions_in_relationship_filter_limit(object_fields)
          ].flatten
        end

        def validate_fields_limit(object_fields)
          return [] unless object_fields

          fields_by_object = object_fields.group_by { |field| field['object_key'] }

          check_collection_limits(fields_by_object, MAX_FIELDS_PER_OBJECT, :excessive_custom_objects_v2_fields)
        end

        def validate_selection_field_limits(object_fields)
          SELECTION_FIELD_LIMITS.map do |field_type, max_limit|
            validate_field_type_limit(object_fields, field_type, max_limit)
          end.flatten
        end

        def validate_field_type_limit(object_fields, field_type, max_limit)
          return [] unless object_fields

          fields_by_object = object_fields
                             .select { |field| field['type'] == field_type }
                             .group_by { |field| field['object_key'] }

          error = field_type == 'dropdown' ? # rubocop:disable Style/MultilineTernaryOperator
                  :excessive_cov2_dropdown_fields_per_object :
                  :excessive_cov2_multiselect_fields_per_object

          check_collection_limits(fields_by_object, max_limit, error, field_type: field_type)
        end

        def validate_selection_field_options_limits(object_fields)
          SELECTION_FIELD_OPTIONS_LIMITS.map do |field_type, max_limit|
            validate_options_limit(object_fields, field_type, max_limit)
          end.flatten
        end

        def validate_options_limit(object_fields, field_type, max_limit)
          return [] unless object_fields

          fields_with_options = object_fields.select do |field|
            field['type'] == field_type && field['custom_field_options']
          end

          [].tap do |errors|
            fields_with_options.each do |field|
              options = field['custom_field_options']
              next if options.size <= max_limit

              errors << ValidationError.new(:excessive_cov2_field_options,
                                            max: max_limit,
                                            count: options.size,
                                            field_key: field['key'],
                                            object_key: field['object_key'])
            end
          end
        end

        def validate_conditions_in_relationship_filter_limit(object_fields)
          return [] unless object_fields

          object_fields
            .select { |field| field['relationship_filter'] }
            .flat_map { |field| validate_relationship_filter_conditions(field) }
        end

        def validate_relationship_filter_conditions(field)
          relationship_filter = field['relationship_filter']
          total_conditions = count_conditions(relationship_filter)

          return [] unless total_conditions > MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT

          [ValidationError.new(:excessive_cov2_relationship_filter_conditions,
                               max: MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT,
                               count: total_conditions,
                               field_key: field['key'],
                               object_key: field['object_key'])]
        end

        # ========== TRIGGERS VALIDATION ==========

        def validate_triggers_excessive_limit(custom_objects_v2_requirements)
          [
            validate_triggers_limit(custom_objects_v2_requirements),
            validate_triggers_conditions_limit(custom_objects_v2_requirements),
            validate_triggers_actions_limit(custom_objects_v2_requirements)
          ].flatten
        end

        def validate_triggers_limit(custom_objects_v2_requirements)
          triggers = custom_objects_v2_requirements['object_triggers']
          return [] unless triggers

          triggers_by_object = triggers.group_by { |trigger| trigger['object_key'] }

          check_collection_limits(triggers_by_object, MAX_TRIGGERS_PER_OBJECT, :excessive_custom_objects_v2_triggers)
        end

        def validate_triggers_conditions_limit(custom_objects_v2_requirements)
          triggers = custom_objects_v2_requirements['object_triggers']
          return [] unless triggers

          triggers.flat_map do |trigger|
            validate_trigger_conditions(trigger)
          end
        end

        def validate_trigger_conditions(trigger)
          return [] unless trigger['conditions'].is_a?(Hash)

          conditions = trigger['conditions']
          total_conditions = count_conditions(conditions)

          return [] unless total_conditions > MAX_CONDITIONS_PER_TRIGGER

          [ValidationError.new(:excessive_custom_objects_v2_trigger_conditions,
                               max: MAX_CONDITIONS_PER_TRIGGER,
                               count: total_conditions,
                               trigger_title: trigger['title'])]
        end

        def validate_triggers_actions_limit(custom_objects_v2_requirements)
          triggers = custom_objects_v2_requirements['object_triggers']
          return [] unless triggers

          [].tap do |errors|
            triggers.each do |trigger|
              next unless trigger['actions']

              actions = trigger['actions']
              next if actions.size <= MAX_ACTIONS_PER_TRIGGER

              errors << ValidationError.new(:excessive_custom_objects_v2_trigger_actions,
                                            max: MAX_ACTIONS_PER_TRIGGER,
                                            count: actions.size,
                                            trigger_title: trigger['title'])
            end
          end
        end

        # ========== SCHEMA VALIDATION ==========

        def validate_objects_schema(custom_objects_v2_requirements)
          objects = custom_objects_v2_requirements['objects']
          return [] unless objects

          objects.flat_map do |object|
            validate_object_schema(object)
          end
        end

        def validate_object_schema(object)
          required_keys = %w[key title title_pluralized include_in_list_view]
          missing_keys = required_keys - object.keys

          missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_object_schema_key,
                                missing_key: missing_key,
                                object_key: object['key'] || '(undefined)')
          end
        end

        def validate_fields_schema(custom_objects_v2_requirements)
          object_fields = custom_objects_v2_requirements['object_fields']
          return [] unless object_fields

          object_fields.flat_map do |field|
            validate_field_schema(field)
          end
        end

        def validate_field_schema(field)
          required_keys = %w[key title type object_key]
          missing_keys = required_keys - field.keys

          missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_field_schema_key,
                                missing_key: missing_key,
                                field_key: field['key'],
                                object_key: field['object_key'] || '(undefined)')
          end
        end

        def validate_triggers_schema(custom_objects_v2_requirements)
          triggers = custom_objects_v2_requirements['object_triggers']
          return [] unless triggers

          triggers.flat_map do |trigger|
            validate_trigger_schema(trigger)
          end
        end

        def validate_trigger_schema(trigger)
          required_keys = %w[object_key title actions conditions]
          missing_keys = required_keys - trigger.keys

          errors = missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_trigger_schema_key,
                                missing_key: missing_key,
                                trigger_title: trigger['title'],
                                object_key: trigger['object_key'] || '(undefined)')
          end

          if trigger['conditions'].is_a?(Hash) && trigger['conditions'].empty?
            errors << ValidationError.new(:empty_cov2_trigger_conditions,
                                          trigger_title: trigger['title'],
                                          object_key: trigger['object_key'])
          end

          errors
        end

        # ========== HELPER METHODS ==========

        def count_conditions(conditions)
          return 0 unless conditions.is_a?(Hash)

          %w[all any].sum { |key| conditions[key]&.size || 0 }
        end

        def check_collection_limits(grouped_items, max_limit, error, **context)
          [].tap do |errors|
            grouped_items.each do |object_key, items|
              next unless items.size > max_limit

              errors << ValidationError.new(error,
                                            max: max_limit,
                                            count: items.size,
                                            object_key: object_key,
                                            **context)
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
