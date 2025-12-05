# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      module Constants
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

        SCHEMA_KEYS = {
          objects: 'objects',
          object_fields: 'object_fields',
          object_triggers: 'object_triggers'
        }.freeze

        OBJECT_KEY = 'object_key'
        TYPE = 'type'
        KEY = 'key'
        TITLE = 'title'
        CF_OPTIONS = 'custom_field_options'
        RELATIONSHIP_FILTER = 'relationship_filter'
        DROPDOWN = 'dropdown'
        MULTISELECT = 'multiselect'
        CONDITIONS = 'conditions'
        ACTIONS = 'actions'
        ALL = 'all'
        ANY = 'any'

        SELECTION_FIELD_LIMITS = {
          DROPDOWN => MAX_DROPDOWN_FIELDS_PER_OBJECT,
          MULTISELECT => MAX_MULTISELECT_FIELDS_PER_OBJECT
        }.freeze

        SELECTION_FIELD_OPTIONS_LIMITS = {
          DROPDOWN => MAX_DROPDOWN_OPTIONS_PER_FIELD,
          MULTISELECT => MAX_MULTISELECT_OPTIONS_PER_FIELD
        }.freeze

        UNDEFINED_VALUE = '(undefined)'
        CONDITION_KEYS = [ALL, ANY].freeze
        MAX_PAYLOAD_SIZE_BYTES = 1_048_576 # 1 MB in bytes

        REFERENCE_VALIDATION_CONFIG = {
          SCHEMA_KEYS[:object_fields] => { identifier: KEY, error: :invalid_cov2_object_reference_in_fields_v2 },
          SCHEMA_KEYS[:object_triggers] => { identifier: KEY, error: :invalid_cov2_object_reference_in_triggers_v2 }
        }.freeze
      end
    end
  end
end
