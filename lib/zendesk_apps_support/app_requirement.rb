# frozen_string_literal: true

module ZendeskAppsSupport
  class AppRequirement
    CUSTOM_OBJECTS_KEY = 'custom_objects'
    CUSTOM_OBJECTS_TYPE_KEY = 'custom_object_types'
    CUSTOM_OBJECTS_RELATIONSHIP_TYPE_KEY = 'custom_object_relationship_types'
    TYPES = %w[automations channel_integrations custom_objects macros targets views ticket_fields
               triggers user_fields organization_fields].freeze
  end
end
