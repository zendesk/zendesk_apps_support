# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::CustomObjectsV2::SchemaValidator do
  describe '.validate' do
    [
      {
        error: :missing_cov2_object_schema_key,
        requirements: {
          'objects' => [{ 'title' => 'Object 1', 'title_pluralized' => 'Objects 1', 'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => []
        },
        description: 'objects is missing required key'
      },
      {
        error: :missing_cov2_field_schema_key,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [{ 'key' => 'field_1', 'title' => 'Field 1', 'type' => 'text' }],
          'object_triggers' => []
        },
        description: 'fields is missing required key'
      },
      {
        error: :missing_cov2_trigger_schema_key_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => [{ 'title' => 'Trigger 1', 'conditions' => { 'all' => [] }, 'actions' => [] }]
        },
        description: 'triggers is missing required key'
      },
      {
        error: :invalid_cov2_trigger_conditions_structure_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'object_key' => 'object_1',
            'title' => 'Trigger 1',
            'actions' => [{ 'field' => 'status', 'value' => 'resolved' }],
            'conditions' => {}
          }]
        },
        description: 'triggers has invalid conditions structure'
      },
      {
        error: :empty_cov2_trigger_conditions_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'object_key' => 'object_1',
            'title' => 'Trigger 1',
            'actions' => [{ 'field' => 'status', 'value' => 'resolved' }],
            'conditions' => { 'all' => [], 'any' => [] }
          }]
        },
        description: 'triggers has empty conditions'
      },
      {
        error: :invalid_cov2_trigger_actions_structure_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'object_key' => 'object_1',
            'title' => 'Trigger 1',
            'actions' => 'not_an_array',
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
          }]
        },
        description: 'triggers has invalid actions structure'
      },
      {
        error: :empty_cov2_trigger_actions_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'object_key' => 'object_1',
            'title' => 'Trigger 1',
            'actions' => [],
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
          }]
        },
        description: 'triggers has empty actions'
      },
      {
        error: :cov2_object_setting_placeholder_not_allowed,
        requirements: {
          'objects' => [
            {
              'key' => 'object_1',
              'title' => '{{ setting.object_title }}',
              'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true
            }
          ],
          'object_fields' => [],
          'object_triggers' => []
        },
        description: 'object contains setting placeholder in value'
      },
      {
        error: :cov2_field_setting_placeholder_not_allowed,
        requirements: {
          'objects' => [
            {
              'key' => 'object_1',
              'title' => 'Object 1',
              'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true
            }
          ],
          'object_fields' => [
      {
        'key' => 'field_1',
        'title' => '{{ setting.field_title }}',
        'type' => 'text',
        'object_key' => 'object_1'
      }
    ],
          'object_triggers' => []
        },
        description: 'field contains setting placeholder in value'
      },
      {
        error: :cov2_trigger_setting_placeholder_not_allowed,
        requirements: {
          'objects' => [
            {
              'key' => 'object_1',
              'title' => 'Object 1',
              'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true
            }
          ],
          'object_fields' => [],
          'object_triggers' => [
      {
        'key' => 'trigger_1',
        'object_key' => 'object_1',
        'title' => '{{ setting.trigger_title }}',
        'actions' => [{ 'field' => 'status', 'value' => 'resolved' }],
        'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
      }
    ]
        },
        description: 'trigger contains setting placeholder in title'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it "raises #{test_case[:error]} validation error" do
          errors = described_class.validate(test_case[:requirements])
          expect(errors.first.key).to eq(test_case[:error])
        end
      end
    end

    [
      {
        requirements: {
          'objects' => [
            {
              'key' => 'ticket_object',
              'title' => 'Ticket Object',
              'title_pluralized' => 'Ticket Objects',
              'include_in_list_view' => true
            }
          ],
          'object_fields' => [
            {
              'key' => 'priority_field',
              'type' => 'text',
              'title' => 'Priority Field',
              'object_key' => 'ticket_object'
            }
          ],
          'object_triggers' => [
            {
              'key' => 'trigger_1',
              'object_key' => 'ticket_object',
              'title' => 'Priority Trigger',
              'actions' => [{ 'field' => 'status', 'value' => 'resolved' }],
              'conditions' => { 'all' => [{ 'field' => 'priority', 'operator' => 'is', 'value' => 'high' }] }
            }
          ]
        },
        description: 'all schema components are valid'
      },
      {
        requirements: {
          'objects' => [
            {
              'key' => 'user_object',
              'title' => 'User Object',
              'title_pluralized' => 'User Objects',
              'include_in_list_view' => false
            }
          ],
          'object_fields' => [
            {
              'key' => 'department_field',
              'type' => 'dropdown',
              'title' => 'Department Field',
              'object_key' => 'user_object'
            }
          ],
          'object_triggers' => [
            {
              'key' => 'trigger_1',
              'object_key' => 'user_object',
              'title' => 'Department Trigger',
              'actions' => [{ 'field' => 'assignee', 'value' => 'manager' }],
              'conditions' => { 'any' => [{ 'field' => 'department', 'operator' => 'contains', 'value' => 'support' }] }
            }
          ]
        },
        description: 'schema with any conditions is valid'
      },
      {
        requirements: {
          'objects' => [
            {
              'key' => 'task_object',
              'title' => 'Task Object',
              'title_pluralized' => 'Task Objects',
              'include_in_list_view' => true
            }
          ],
          'object_fields' => [
            {
              'key' => 'status_field',
              'type' => 'checkbox',
              'title' => 'Status Field',
              'object_key' => 'task_object'
            }
          ],
          'object_triggers' => [
            {
              'key' => 'trigger_1',
              'object_key' => 'task_object',
              'title' => 'Mixed Trigger',
              'actions' => [{ 'field' => 'priority', 'value' => 'urgent' }],
              'conditions' => {
                'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'pending' }],
                'any' => [{ 'field' => 'assignee', 'operator' => 'is_not', 'value' => 'null' }]
              }
            }
          ]
        },
        description: 'schema with both all and any conditions is valid'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns no validation errors' do
          errors = described_class.validate(test_case[:requirements])
          expect(errors).to be_empty
        end
      end
    end
  end
end
