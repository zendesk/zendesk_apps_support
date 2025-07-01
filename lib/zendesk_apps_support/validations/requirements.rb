# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000
      MAX_CUSTOM_OBJECTS_REQUIREMENTS = 50

      class << self
        def call(package)
          if package.manifest.requirements_only? && !package.has_requirements?
            return [ValidationError.new(:missing_requirements)]
          elsif !supports_requirements(package) && package.has_requirements?
            return [ValidationError.new(:requirements_not_supported)]
          elsif !package.has_requirements?
            return []
          end

          begin
            requirements = package.requirements_json
          rescue ZendeskAppsSupport::Manifest::OverrideError => e
            return [ValidationError.new(:duplicate_requirements, duplicate_keys: e.key, count: 1)]
          end

          [].tap do |errors|
            errors << invalid_requirements_types(requirements)
            errors << excessive_requirements(requirements)
            errors << excessive_custom_objects_requirements(requirements)
            errors << invalid_channel_integrations(requirements)
            errors << invalid_custom_fields(requirements)
            errors << invalid_custom_objects(requirements)
            errors << invalid_webhooks(requirements)
            errors << invalid_target_types(requirements)
            errors << missing_required_fields(requirements)
            errors << invalid_custom_objects_v2(requirements)
            errors.flatten!
            errors.compact!
          end
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def supports_requirements(package)
          !package.manifest.marketing_only? && package.manifest.products_ignore_locations != [Product::CHAT]
        end

        def missing_required_fields(requirements)
          [].tap do |errors|
            requirements.each do |requirement_type, requirement|
              next if %w[channel_integrations custom_objects webhooks custom_objects_v2].include? requirement_type
              requirement.each do |identifier, fields|
                next if fields.nil? || fields.include?('title')
                errors << ValidationError.new(:missing_required_fields,
                                              field: 'title',
                                              identifier: identifier)
              end
            end
          end
        end

        def excessive_requirements(requirements)
          count = requirements.values.map do |req|
            req.is_a?(Hash) ? req.values : req
          end.flatten.size
          ValidationError.new(:excessive_requirements, max: MAX_REQUIREMENTS, count: count) if count > MAX_REQUIREMENTS
        end

        def excessive_custom_objects_requirements(requirements)
          custom_objects = requirements[AppRequirement::CUSTOM_OBJECTS_KEY]
          return unless custom_objects

          count = custom_objects.values.flatten.size
          if count > MAX_CUSTOM_OBJECTS_REQUIREMENTS
            ValidationError.new(:excessive_custom_objects_requirements, max: MAX_CUSTOM_OBJECTS_REQUIREMENTS,
                                                                        count: count)
          end
        end

        def invalid_custom_fields(requirements)
          user_fields = requirements['user_fields']
          organization_fields = requirements['organization_fields']
          return if user_fields.nil? && organization_fields.nil?
          [].tap do |errors|
            [user_fields, organization_fields].compact.each do |field_group|
              field_group.each do |identifier, fields|
                next if fields.include? 'key'
                errors << ValidationError.new(:missing_required_fields,
                                              field: 'key',
                                              identifier: identifier)
              end
            end
          end
        end

        def invalid_channel_integrations(requirements)
          channel_integrations = requirements['channel_integrations']
          return unless channel_integrations
          [].tap do |errors|
            if channel_integrations.size > 1
              errors << ValidationError.new(:multiple_channel_integrations)
            end
            channel_integrations.each do |identifier, fields|
              next if fields.include? 'manifest_url'
              errors << ValidationError.new(:missing_required_fields,
                                            field: 'manifest_url',
                                            identifier: identifier)
            end
          end
        end

        def invalid_webhooks(requirements)
          webhook_requirements = requirements[AppRequirement::WEBHOOKS_KEY]

          return if webhook_requirements.nil?

          webhook_requirements.map do |identifier, requirement|
            validate_webhook_keys(identifier, requirement)
          end.flatten
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

        def invalid_custom_objects_v2(requirements)
          custom_objects_v2_requirements = requirements[AppRequirement::CUSTOM_OBJECTS_VERSION_2_KEY]
          return if custom_objects_v2_requirements.nil?

          validate_custom_objects_v2_keys(custom_objects_v2_requirements)
        end

        def validate_custom_objects_v2_keys(custom_objects_v2_requirements)
          errors = []

          # Check if objects array exists
          objects = custom_objects_v2_requirements['objects']
          return if objects.nil?

          required_object_keys = %w[key include_in_list_view title title_pluralized]

          objects.each_with_index do |object, index|
            missing_keys = required_object_keys - object.keys

            missing_keys.each do |key|
              errors << ValidationError.new(:missing_required_fields,
                                          field: key,
                                          identifier: "#{AppRequirement::CUSTOM_OBJECTS_VERSION_2_KEY} objects[#{index}]")
            end
          end

          # Validate object_triggers if present
          object_triggers = custom_objects_v2_requirements['object_triggers']
          if object_triggers
            errors.concat(validate_object_triggers(object_triggers, objects))
          end

          errors
        end

        def validate_object_triggers(object_triggers, objects)
          errors = []
          return errors if object_triggers.nil? || objects.nil?

          # Get all valid field names from objects
          valid_fields = objects.flat_map do |obj|
            fields = obj['fields'] || []
            fields.map { |field| field['key'] }
          end.compact.uniq

          object_triggers.each_with_index do |trigger, index|
            trigger_identifier = "object_triggers[#{index}]"

            # Validate required keys for trigger
            required_trigger_keys = %w[key title conditions actions]
            missing_keys = required_trigger_keys - trigger.keys

            missing_keys.each do |key|
              errors << ValidationError.new(:missing_required_fields,
                                          field: key,
                                          identifier: trigger_identifier)
            end

            # Validate actions array
            if trigger['actions']
              trigger['actions'].each_with_index do |action, action_index|
                action_identifier = "#{trigger_identifier}.actions[#{action_index}]"

                # Each action must have 'field' and 'value'
                required_action_keys = %w[field value]
                missing_action_keys = required_action_keys - action.keys

                missing_action_keys.each do |key|
                  errors << ValidationError.new(:missing_required_fields,
                                              field: key,
                                              identifier: action_identifier)
                end
              end
            end

            # Validate conditions
            if trigger['conditions']
              errors.concat(validate_trigger_conditions(trigger['conditions'], valid_fields, trigger_identifier))
            end
          end

          errors
        end

        def validate_trigger_conditions(conditions, valid_fields, trigger_identifier)
          errors = []

          # Conditions can have 'all' and/or 'any' keys
          %w[all any].each do |condition_type|
            next unless conditions[condition_type]

            unless conditions[condition_type].is_a?(Array)
              errors << ValidationError.new(:missing_required_fields,
                                          field: "conditions.#{condition_type} (must be array)",
                                          identifier: trigger_identifier)
              next
            end

            conditions[condition_type].each_with_index do |condition, condition_index|
              condition_identifier = "#{trigger_identifier}.conditions.#{condition_type}[#{condition_index}]"

              # Each condition must have 'field'
              unless condition.key?('field')
                errors << ValidationError.new(:missing_required_fields,
                                            field: 'field',
                                            identifier: condition_identifier)
              else
                # Validate that field exists in objects - use existing error format
                field_name = condition['field']
                unless valid_fields.include?(field_name)
                  errors << ValidationError.new(:missing_required_fields,
                                              field: "field '#{field_name}' (must reference valid object field: #{valid_fields.join(', ')})",
                                              identifier: condition_identifier)
                end
              end
            end
          end

          errors
        end

        def invalid_custom_objects(requirements)
          custom_objects = requirements[AppRequirement::CUSTOM_OBJECTS_KEY]
          return if custom_objects.nil?

          [].tap do |errors|
            unless custom_objects.key?(AppRequirement::CUSTOM_OBJECTS_TYPE_KEY)
              errors << ValidationError.new(:missing_required_fields,
                                            field: AppRequirement::CUSTOM_OBJECTS_TYPE_KEY,
                                            identifier: AppRequirement::CUSTOM_OBJECTS_KEY)
            end

            valid_schema = {
              AppRequirement::CUSTOM_OBJECTS_TYPE_KEY => %w[key schema],
              AppRequirement::CUSTOM_OBJECTS_RELATIONSHIP_TYPE_KEY => %w[key source target]
            }

            valid_schema.keys.each do |requirement_type|
              (custom_objects[requirement_type] || []).each do |requirement|
                validate_custom_objects_keys(requirement.keys, valid_schema[requirement_type], requirement_type, errors)
              end
            end
          end
        end

        def invalid_requirements_types(requirements)
          invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES
          unless invalid_types.empty?
            ValidationError.new(:invalid_requirements_types,
                                invalid_types: invalid_types.join(', '),
                                count: invalid_types.length)
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

        def invalid_target_types(requirements)
          invalid_target_types = %w[http_target url_target_v2]

          requirements['targets']&.map do |_identifier, requirement|
            if invalid_target_types.include?(requirement['type'])
              ValidationError.new(:invalid_requirements_types,
                                  invalid_types: "targets -> #{requirement['type']}",
                                  count: 1)
            end
          end
        end
      end
    end
  end
end
