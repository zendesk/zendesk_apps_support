# frozen_string_literal: true

class BuildErrors
  def self.build_errors(requirements, obj=nil)
    subclasses_errors = ObjectSpace.each_object(Class).select { |klass| klass < self }

    errors = []
    subclasses_errors.each do |subclasse_error| 
      errors << subclasse_error.invalid_requirements(requirements, obj=obj)
    end
    return errors
  end

  def invalid_requirements(requirements, obj=nil)
    raise NotImplementedError, "Must be implemented in a subclass" 
  end
end

class InvalidCustomFields < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
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
end

class InvalidCustomObjects < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    custom_objects = requirements[ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_KEY]
    return if custom_objects.nil?

    [].tap do |errors|
      unless custom_objects.key?(ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_TYPE_KEY)
        errors << ValidationError.new(:missing_required_fields,
                                      field: ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_TYPE_KEY,
                                      identifier: ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_KEY)
      end

      valid_schema = {
        ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_TYPE_KEY => %w[key schema],
        ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_RELATIONSHIP_TYPE_KEY => %w[key source target]
      }

      valid_schema.keys.each do |requirement_type|
        (custom_objects[requirement_type] || []).each do |requirement|
          obj.send(:validate_custom_objects_keys, requirement.keys, 
              valid_schema[requirement_type], requirement_type, errors)
        end
      end
    end
  end
end

class InvalidRequirementsTypes < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES
    unless invalid_types.empty?
      ValidationError.new(:invalid_requirements_types,
                          invalid_types: invalid_types.join(', '),
                          count: invalid_types.length)
    end
  end
end

class InvalidChannelIntegrations < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
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
end

class InvalidWebhooks < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    webhook_requirements = requirements[ZendeskAppsSupport::AppRequirement::WEBHOOKS_KEY]

    return if webhook_requirements.nil?

    webhook_requirements.map do |identifier, requirement|
      obj.send(:validate_webhook_keys, identifier, requirement)
    end.flatten
  end
end

class ExcessiveCustomObjectsRequirements < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    custom_objects = requirements[ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_KEY]
    return unless custom_objects

    count = custom_objects.values.flatten.size
    if count > obj::MAX_CUSTOM_OBJECTS_REQUIREMENTS
      ValidationError.new(:excessive_custom_objects_requirements, max: obj::MAX_CUSTOM_OBJECTS_REQUIREMENTS,
                                                                  count: count)
    end
  end
end

class ExcessiveRequirements < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    count = requirements.values.map do |req|
      req.is_a?(Hash) ? req.values : req
    end.flatten.size
    ValidationError.new(:excessive_requirements, max: obj::MAX_REQUIREMENTS, count: count) if count > obj::MAX_REQUIREMENTS
  end
end

class MissingRequiredFields < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
    [].tap do |errors|
      requirements.each do |requirement_type, requirement|
        next if %w[channel_integrations custom_objects webhooks].include? requirement_type
        requirement.each do |identifier, fields|
          next if fields.nil? || fields.include?('title')
          errors << ValidationError.new(:missing_required_fields,
                                        field: 'title',
                                        identifier: identifier)
        end
      end
    end
  end
end

class InvalidTargetTypes < BuildErrors
  def self.invalid_requirements(requirements, obj=nil)
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

module ZendeskAppsSupport
  module Validations
    module Requirements
      MAX_REQUIREMENTS = 5000
      MAX_CUSTOM_OBJECTS_REQUIREMENTS = 50

      class << self
        def call(package)
          unless package.has_requirements?
            return [ValidationError.new(:missing_requirements)] if package.manifest.requirements_only?

            return []
          end

          return [ValidationError.new(:requirements_not_supported)] unless supports_requirements(package)

          begin
            requirements = package.requirements_json
          rescue ZendeskAppsSupport::Manifest::OverrideError => e
            return [ValidationError.new(:duplicate_requirements, duplicate_keys: e.key, count: 1)]
          end

          build_errors(requirements)
        rescue JSON::ParserError => e
          return [ValidationError.new(:requirements_not_json, errors: e)]
        end

        private

        def supports_requirements(package)
          !package.manifest.marketing_only? && package.manifest.products_ignore_locations != [Product::CHAT]
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

        def validate_custom_objects_keys(keys, expected_keys, identifier, errors = [])
          missing_keys = expected_keys - keys
          missing_keys.each do |key|
            errors << ValidationError.new(:missing_required_fields,
                                          field: key,
                                          identifier: identifier)
          end
        end

        def build_errors(requirements)
          [].tap do |errors|
            BuildErrors.build_errors(requirements, self).each { |error| errors << error}
            errors.flatten!
            errors.compact!
          end
        end
      end
    end
  end
end
