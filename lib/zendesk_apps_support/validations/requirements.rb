# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000

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
            errors << invalid_channel_integrations(requirements)
            errors << invalid_custom_fields(requirements)
            errors << invalid_custom_objects(requirements)
            errors << missing_required_fields(requirements)
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
              next if %w[channel_integrations custom_objects].include? requirement_type
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

        def invalid_custom_objects(requirements)
          custom_objects = requirements['custom_objects']
          return unless custom_objects

          valid_schema = {
            'custom_object_types' => %w[key schema],
            'custom_object_relationship_types' => %w[key source target]
          }

          [].tap do |errors|
            validate_custom_objects_keys(custom_objects.keys, valid_schema.keys, 'custom_objects', errors)

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
          invalid_keys = keys - expected_keys
          unless invalid_keys.empty?
            errors << ValidationError.new(:invalid_cr_schema_keys, # TODO: update error translations
                                          invalid_keys: invalid_keys.join(', '),
                                          count: invalid_keys.length)
          end
          missing_keys = expected_keys - keys
          missing_keys.each do |key|
            errors << ValidationError.new(:missing_required_fields,
                                          field: key,
                                          identifier: identifier)
          end
        end
      end
    end
  end
end
