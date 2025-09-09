# rubocop:disable Metrics/ModuleLength
# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      SCHEMA_KEYS = {
        objects: 'objects',
        object_fields: 'object_fields',
        object_triggers: 'object_triggers'
      }.freeze

      # Limits
      MAX_OBJECTS = 50
      MAX_FIELDS_PER_OBJECT = 10
      MAX_TRIGGERS_PER_OBJECT = 20
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

      UNDEFINED_VALUE = '(undefined)'
      CONDITION_KEYS = %w[all any].freeze
      MAX_PAYLOAD_SIZE_BYTES = 1_048_576 # 1 MB in bytes

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

        # ============ PAYLOAD SIZE VALIDATION ============

        def validate_payload_size(requirements)
          payload_size = requirements.to_json.bytesize
          return [] if payload_size <= MAX_PAYLOAD_SIZE_BYTES

          [ValidationError.new(:excessive_cov2_payload_size)]
        end

        # ============ STRUCTURAL VALIDATION ============

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

        # ============ VALIDATE LIMITS ============

        def validate_limits(requirements)
          [
            validate_objects_excessive_limit(requirements[SCHEMA_KEYS[:objects]]),
            validate_fields_excessive_limit(requirements[SCHEMA_KEYS[:object_fields]]),
            validate_triggers_excessive_limit(requirements[SCHEMA_KEYS[:object_triggers]])
          ].flatten
        end

        # ============ SCHEMA VALIDATION ============

        def validate_schema(requirements)
          [
            validate_objects_schema(requirements[SCHEMA_KEYS[:objects]]),
            validate_fields_schema(requirements[SCHEMA_KEYS[:object_fields]]),
            validate_triggers_schema(requirements[SCHEMA_KEYS[:object_triggers]])
          ].flatten
        end

        # ========== OBJECTS VALIDATION ==========

        def validate_objects_excessive_limit(objects = [])
          return [] if objects.nil? || objects.size <= MAX_OBJECTS

          [ValidationError.new(:excessive_custom_objects_v2_requirements,
                               max: MAX_OBJECTS,
                               count: objects.size)]
        end

        # ========== FIELDS VALIDATION ==========

        def validate_fields_excessive_limit(object_fields = [])
          return [] unless object_fields&.any?

          valid_fields = object_fields
                         .select { |field| field.is_a?(Hash) }
                         .reject { |field| field['object_key'].to_s.empty? }

          [
            validate_fields_limit(valid_fields),
            validate_selection_field_limits(valid_fields),
            validate_selection_field_options_limits(valid_fields),
            validate_conditions_in_relationship_filter_limit(valid_fields)
          ].flatten
        end

        def validate_fields_limit(object_fields)
          fields_by_object = object_fields.group_by { |field| field['object_key'] }

          validate_collection_limits(fields_by_object, MAX_FIELDS_PER_OBJECT, :excessive_custom_objects_v2_fields)
        end

        def validate_selection_field_limits(object_fields)
          SELECTION_FIELD_LIMITS.flat_map do |field_type, max_limit|
            validate_field_type_limit(object_fields, field_type, max_limit)
          end
        end

        def validate_field_type_limit(object_fields, field_type, max_limit)
          fields_by_object = object_fields
                             .select { |field| field['type'] == field_type }
                             .group_by { |field| field['object_key'] }

          validate_collection_limits(fields_by_object, max_limit, :excessive_cov2_selection_fields_per_object,
                                     field_type: field_type)
        end

        def validate_selection_field_options_limits(object_fields)
          SELECTION_FIELD_OPTIONS_LIMITS.flat_map do |field_type, max_limit|
            validate_options_limit(object_fields, field_type, max_limit)
          end
        end

        def validate_options_limit(object_fields, field_type, max_limit)
          fields_with_options = object_fields.select do |field|
            field['type'] == field_type && field['custom_field_options']&.any?
          end

          fields_with_options.filter_map do |field|
            options = field['custom_field_options']

            next if options.size <= max_limit

            ValidationError.new(:excessive_cov2_field_options,
                                max: max_limit,
                                count: options.size,
                                field_key: field['key'],
                                object_key: field['object_key'])
          end
        end

        def validate_conditions_in_relationship_filter_limit(object_fields)
          object_fields
            .select { |field| field['relationship_filter'] }
            .flat_map { |field| validate_relationship_filter_conditions(field) }
        end

        def validate_relationship_filter_conditions(field)
          relationship_filter = field['relationship_filter']
          return [] unless relationship_filter

          total_conditions = count_conditions(relationship_filter)

          return [] unless total_conditions > MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT

          [ValidationError.new(:excessive_cov2_relationship_filter_conditions,
                               max: MAX_CONDITIONS_IN_RELATIONSHIP_FILTER_PER_OBJECT,
                               count: total_conditions,
                               field_key: field['key'],
                               object_key: field['object_key'])]
        end

        # ========== TRIGGERS VALIDATION ==========

        def validate_triggers_excessive_limit(object_triggers = [])
          valid_triggers = object_triggers
                           .select { |trigger| trigger.is_a?(Hash) }
                           .reject { |trigger| trigger['object_key'].to_s.empty? }
          return [] unless valid_triggers&.any?

          [
            validate_triggers_limit(valid_triggers),
            validate_triggers_conditions_limit(valid_triggers),
            validate_triggers_actions_limit(valid_triggers)
          ].flatten
        end

        def validate_triggers_limit(object_triggers)
          triggers_by_object = object_triggers.group_by { |trigger| trigger['object_key'] }

          validate_collection_limits(triggers_by_object, MAX_TRIGGERS_PER_OBJECT, :excessive_custom_objects_v2_triggers)
        end

        def validate_triggers_conditions_limit(object_triggers)
          object_triggers.flat_map do |trigger|
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

        def validate_triggers_actions_limit(object_triggers)
          object_triggers.filter_map do |trigger|
            next unless trigger['actions']

            actions = trigger['actions']
            next if actions.size <= MAX_ACTIONS_PER_TRIGGER

            ValidationError.new(:excessive_custom_objects_v2_trigger_actions,
                                max: MAX_ACTIONS_PER_TRIGGER,
                                count: actions.size,
                                trigger_title: trigger['title'])
          end
        end

        # ========== SCHEMA VALIDATION ==========

        def validate_objects_schema(objects = [])
          return [] if objects.nil?

          valid_objects = objects.select { |object| object.is_a?(Hash) }

          valid_objects.flat_map do |object|
            validate_object_schema(object)
          end
        end

        def validate_object_schema(object)
          required_keys = %w[key title title_pluralized include_in_list_view]
          missing_keys = required_keys - object.keys

          missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_object_schema_key,
                                missing_key: missing_key,
                                object_key: object['key'] || UNDEFINED_VALUE)
          end
        end

        def validate_fields_schema(object_fields = [])
          return [] unless object_fields&.any?

          valid_fields = object_fields.select { |field| field.is_a?(Hash) }

          valid_fields.flat_map do |field|
            validate_field_schema(field)
          end
        end

        def validate_field_schema(field)
          required_keys = %w[key title type object_key]
          missing_keys = required_keys - field.keys

          missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_field_schema_key,
                                missing_key: missing_key,
                                field_key: field['key'] || UNDEFINED_VALUE,
                                object_key: field['object_key'] || UNDEFINED_VALUE)
          end
        end

        def validate_triggers_schema(object_triggers = [])
          return [] unless object_triggers&.any?

          valid_triggers = object_triggers.select { |trigger| trigger.is_a?(Hash) }

          valid_triggers.flat_map do |trigger|
            validate_trigger_schema(trigger)
          end
        end

        def validate_trigger_schema(trigger)
          required_keys = %w[object_key title actions conditions]
          missing_keys = required_keys - trigger.keys

          errors = missing_keys.map do |missing_key|
            ValidationError.new(:missing_cov2_trigger_schema_key,
                                missing_key: missing_key,
                                trigger_title: trigger['title'] || UNDEFINED_VALUE,
                                object_key: trigger['object_key'] || UNDEFINED_VALUE)
          end

          errors.concat(validate_conditions_schema(trigger['conditions'], trigger['object_key'], trigger['title']))
          errors.concat(validate_actions_schema(trigger['actions'], trigger['object_key'], trigger['title']))
          errors
        end

        def validate_conditions_schema(conditions, object_key = UNDEFINED_VALUE, title = UNDEFINED_VALUE)
          error_data = { trigger_title: title, object_key: object_key }

          unless valid_conditions_structure?(conditions)
            return [ValidationError.new(:invalid_cov2_trigger_conditions_structure, **error_data)]
          end

          if count_conditions(conditions).zero?
            return [ValidationError.new(:empty_cov2_trigger_conditions, **error_data)]
          end

          []
        end

        def validate_actions_schema(actions, object_key = UNDEFINED_VALUE, title = UNDEFINED_VALUE)
          error_data = { trigger_title: title, object_key: object_key }

          unless actions.is_a?(Array)
            return [ValidationError.new(:invalid_cov2_trigger_actions_structure, **error_data)]
          end

          return [] unless actions.empty?

          [ValidationError.new(:empty_cov2_trigger_actions, **error_data)]
        end

        # ========== HELPER METHODS ==========

        def count_conditions(conditions)
          return 0 unless conditions.is_a?(Hash)

          CONDITION_KEYS.sum { |key| conditions[key]&.size || 0 }
        end

        def validate_collection_limits(grouped_items, max_limit, error, **context)
          grouped_items.filter_map do |object_key, items|
            next if items.size <= max_limit

            ValidationError.new(error,
                                max: max_limit,
                                count: items.size,
                                object_key: object_key,
                                **context)
          end
        end

        def valid_conditions_structure?(conditions)
          return false unless conditions.is_a?(Hash)

          (conditions.key?('all') || conditions.key?('any')) &&
            CONDITION_KEYS.all? { |key| conditions[key].nil? || conditions[key].is_a?(Array) }
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
# rubocop:enable Metrics/ModuleLength
