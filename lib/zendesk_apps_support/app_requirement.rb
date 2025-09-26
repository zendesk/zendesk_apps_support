# frozen_string_literal: true

module ZendeskAppsSupport
  class AppRequirement
    WEBHOOKS_KEY = 'webhooks'
    CUSTOM_OBJECTS_KEY = 'custom_objects'
    CUSTOM_OBJECTS_TYPE_KEY = 'custom_object_types'
    CUSTOM_OBJECTS_RELATIONSHIP_TYPE_KEY = 'custom_object_relationship_types'
    CUSTOM_OBJECTS_V2_KEY = 'custom_objects_v2'
    CUSTOM_OBJECTS_V2_OBJECTS_KEY = 'objects'
    CUSTOM_OBJECTS_V2_OBJECT_FIELDS_KEY = 'object_fields'
    CUSTOM_OBJECT_V2_OBJECT_TRIGGERS_KEY = 'object_triggers'
    TYPES = %w[automations channel_integrations custom_objects macros targets views ticket_fields
               triggers user_fields organization_fields webhooks custom_objects_v2].freeze
  end
end
