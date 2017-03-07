# frozen_string_literal: true
module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000

      class <<self
        def call(package)
          if package.manifest.requirements_only? && !package.has_requirements?
            return [ValidationError.new(:missing_requirements)]
          elsif package.manifest.marketing_only? && package.has_requirements?
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
            errors << missing_required_fields(requirements)
            errors.flatten!
            errors.compact!
          end
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def missing_required_fields(requirements)
          [].tap do |errors|
            requirements.each do |requirement_type, requirement|
              next if requirement_type == 'channel_integrations'
              requirement.each do |identifier, fields|
                next if fields.include? 'title'
                errors << ValidationError.new(:missing_required_fields, field: 'title', identifier: identifier)
              end
            end
          end
        end

        def excessive_requirements(requirements)
          count = requirements.values.map(&:values).flatten.size
          ValidationError.new(:excessive_requirements, max: MAX_REQUIREMENTS, count: count) if count > MAX_REQUIREMENTS
        end

        def invalid_custom_fields(requirements)
          user_fields = requirements['user_fields'] || {}
          organization_fields = requirements['organization_fields'] || {}
          custom_fields = user_fields.merge(organization_fields)
          return if custom_fields.empty?
          [].tap do |errors|
            custom_fields.each do |identifier, fields|
              next if fields.include? 'key'
              errors << ValidationError.new(:missing_required_fields, field: 'key', identifier: identifier)
            end
          end
        end

        def invalid_channel_integrations(requirements)
          channel_integrations = requirements['channel_integrations']
          return unless channel_integrations
          [].tap do |errors|
            if channel_integrations.size > 1
              errors << ValidationError.new(:multiple_channel_integrations, count: channel_integrations.size)
            end
            channel_integrations.each do |identifier, fields|
              unless fields.include? 'manifest_url'
                errors << ValidationError.new(:missing_required_fields, field: 'manifest_url', identifier: identifier)
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
      end
    end
  end
end
