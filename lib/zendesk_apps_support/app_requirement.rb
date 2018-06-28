# frozen_string_literal: true

module ZendeskAppsSupport
  class AppRequirement
    TYPES = %w[automations channel_integrations custom_resources_schema macros targets views ticket_fields
               triggers user_fields organization_fields].freeze
  end
end
