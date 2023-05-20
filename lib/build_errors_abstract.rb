# frozen_string_literal: true

class BuildErrors
  def self.build_errors(requirements, klass=klass)
    subclasses_errors = ObjectSpace.each_object(Class).select { |klass| klass < self }

    errors = []
    subclasses_errors.each do |subclass_error| 
      errors << subclass_error.invalid_requirements(requirements, klass=klass)
    end
    return errors
  end

  def self.invalid_requirements(requirements, klass=klass)
    raise NotImplementedError, "Must be implemented in a subclass" 
  end
end

class InvalidCustomFields < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
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
  def self.invalid_requirements(requirements, klass=klass)
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
          klass.send(:validate_custom_objects_keys, requirement.keys, 
              valid_schema[requirement_type], requirement_type, errors)
        end
      end
    end
  end
end

class InvalidRequirementsTypes < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
    invalid_types = requirements.keys - ZendeskAppsSupport::AppRequirement::TYPES
    unless invalid_types.empty?
      ValidationError.new(:invalid_requirements_types,
                          invalid_types: invalid_types.join(', '),
                          count: invalid_types.length)
    end
  end
end

class InvalidChannelIntegrations < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
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
  def self.invalid_requirements(requirements, klass=klass)
    webhook_requirements = requirements[ZendeskAppsSupport::AppRequirement::WEBHOOKS_KEY]

    return if webhook_requirements.nil?

    webhook_requirements.map do |identifier, requirement|
      klass.send(:validate_webhook_keys, identifier, requirement)
    end.flatten
  end
end

class ExcessiveCustomObjectsRequirements < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
    custom_objects = requirements[ZendeskAppsSupport::AppRequirement::CUSTOM_OBJECTS_KEY]
    return unless custom_objects

    count = custom_objects.values.flatten.size
    if count > klass::MAX_CUSTOM_OBJECTS_REQUIREMENTS
      ValidationError.new(:excessive_custom_objects_requirements, max: klass::MAX_CUSTOM_OBJECTS_REQUIREMENTS,
                                                                  count: count)
    end
  end
end

class ExcessiveRequirements < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
    count = requirements.values.map do |req|
      req.is_a?(Hash) ? req.values : req
    end.flatten.size
    ValidationError.new(:excessive_requirements, max: klass::MAX_REQUIREMENTS, count: count) if count > klass::MAX_REQUIREMENTS
  end
end

class MissingRequiredFields < BuildErrors
  def self.invalid_requirements(requirements, klass=klass)
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
  def self.invalid_requirements(requirements, klass=klass)
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
