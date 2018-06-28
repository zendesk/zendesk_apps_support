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
            errors << invalid_custom_resources_schema(requirements)
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
              next if %w[channel_integrations custom_resources_schema].include? requirement_type
              requirement.each do |identifier, fields|
                next if fields.include? 'title'
                errors << ValidationError.new(:missing_required_fields,
                                              field: 'title',
                                              identifier: identifier)
              end
            end
          end
        end

        def excessive_requirements(requirements)
          count = requirements.values.map(&:values).flatten.size
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

        def invalid_custom_resources_schema(requirements)
          custom_resources_schema = requirements['custom_resources_schema']
          return unless custom_resources_schema
          valid_schema_keys = %w[resource_types relationship_types]
          [].tap do |errors|
            invalid_keys = custom_resources_schema.keys - valid_schema_keys
            unless invalid_keys.empty?
              errors << ValidationError.new(:invalid_cr_schema_keys,
                                            invalid_keys: invalid_keys.join(', '),
                                            count: invalid_keys.length)
            end

            valid_schema_keys.each do |required_key|
              next if custom_resources_schema.keys.include? required_key
              errors << ValidationError.new(:missing_required_fields,
                                            field: required_key,
                                            identifier: 'custom_resources_schema')
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
      end
    end
  end
end
