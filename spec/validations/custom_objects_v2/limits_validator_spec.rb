# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::CustomObjectsV2::LimitsValidator do
  describe '.validate' do
    [
      {
        error: :excessive_custom_objects_v2_requirements,
        requirements: {
          'objects' => Array.new(51) { |i| { 'key' => "object_#{i}", 'title' => "Object #{i}" } },
          'object_fields' => [],
          'object_triggers' => []
        },
        description: 'there are more than 50 objects'
      },
      {
        error: :excessive_custom_objects_v2_fields,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => Array.new(11) do |i|
            { 'key' => "field_#{i}", 'type' => 'text', 'object_key' => 'object_1' }
          end,
          'object_triggers' => []
        },
        description: 'there are more than 10 fields per object'
      },
      {
        error: :excessive_cov2_selection_fields_per_object,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => Array.new(6) do |i|
            { 'key' => "field_#{i}", 'type' => 'dropdown', 'object_key' => 'object_1' }
          end,
          'object_triggers' => []
        },
        description: 'there are more than 5 dropdown fields per object'
      },
      {
        error: :excessive_cov2_field_options,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => [{
            'key' => 'field_1',
            'type' => 'dropdown',
            'object_key' => 'object_1',
            'custom_field_options' => Array.new(11) { |i| { 'name' => "Option #{i}", 'value' => "value_#{i}" } }
          }],
          'object_triggers' => []
        },
        description: 'there are more than 10 options for a dropdown field'
      },
      {
        error: :excessive_cov2_relationship_filter_conditions,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => [{
            'key' => 'field_1',
            'type' => 'lookup',
            'object_key' => 'object_1',
            'relationship_filter' => {
              'all' => Array.new(21) { |i| { 'field' => "field_#{i}", 'operator' => 'is', 'value' => "value_#{i}" } }
            }
          }],
          'object_triggers' => []
        },
        description: 'there are more than 20 relationship filter conditions'
      },
      {
        error: :excessive_custom_objects_v2_triggers,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => [],
          'object_triggers' => Array.new(21) do |i|
            { 'key' => "trigger_#{i}", 'title' => "Trigger #{i}", 'object_key' => 'object_1',
              'conditions' => { 'all' => [] }, 'actions' => [] }
          end
        },
        description: 'there are more than 20 triggers per object'
      },
      {
        error: :excessive_custom_objects_v2_trigger_conditions_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'title' => 'Trigger 1',
            'object_key' => 'object_1',
            'conditions' => {
              'all' => Array.new(51) { |i| { 'field' => "field_#{i}", 'operator' => 'is', 'value' => "value_#{i}" } }
            },
            'actions' => []
          }]
        },
        description: 'there are more than 50 conditions per trigger'
      },
      {
        error: :excessive_custom_objects_v2_trigger_actions_v2,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1' }],
          'object_fields' => [],
          'object_triggers' => [{
            'key' => 'trigger_1',
            'title' => 'Trigger 1',
            'object_key' => 'object_1',
            'conditions' => { 'all' => [] },
            'actions' => Array.new(26) { |i| { 'field' => "field_#{i}", 'value' => "value_#{i}" } }
          }]
        },
        description: 'there are more than 25 actions per trigger'
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
          'objects' => [{ 'key' => 'order_object', 'title' => 'Order Object' }],
          'object_fields' => [
            {
              'key' => 'status_field',
              'type' => 'dropdown',
              'object_key' => 'order_object',
              'custom_field_options' => Array.new(10) { |i| { 'name' => "Status #{i}", 'value' => "status_#{i}" } }
            },
            {
              'key' => 'lookup_field',
              'type' => 'lookup',
              'object_key' => 'order_object',
              'relationship_filter' => {
                'all' => Array.new(20) { |i| { 'field' => "field_#{i}", 'operator' => 'is', 'value' => "value_#{i}" } }
              }
            }
          ],
          'object_triggers' => [
            {
              'key' => 'order_processing_trigger',
              'title' => 'Order Processing Trigger',
              'object_key' => 'order_object',
              'conditions' => {
                'all' => Array.new(50) { |i| { 'field' => "condition_field_#{i}", 'operator' => 'is', 'value' => "value_#{i}" } }
              },
              'actions' => Array.new(25) { |i| { 'field' => "action_field_#{i}", 'value' => "action_value_#{i}" } }
            }
          ]
        },
        description: 'complex configuration with all limits at maximum'
      },
      {
        requirements: {
          'objects' => [
            { 'key' => 'ticket_object', 'title' => 'Ticket Object' },
            { 'key' => 'user_object', 'title' => 'User Object' }
          ],
          'object_fields' => [
            { 'key' => 'priority_field', 'type' => 'text', 'object_key' => 'ticket_object' },
            { 'key' => 'department_field', 'type' => 'text', 'object_key' => 'user_object' },
            {
              'key' => 'category_field',
              'type' => 'dropdown',
              'object_key' => 'ticket_object',
              'custom_field_options' => [
                { 'name' => 'Bug', 'value' => 'bug' },
                { 'name' => 'Feature', 'value' => 'feature' }
              ]
            }
          ],
          'object_triggers' => [
            {
              'key' => 'assignment_trigger',
              'title' => 'Ticket Assignment Trigger',
              'object_key' => 'ticket_object',
              'conditions' => { 'all' => [{ 'field' => 'priority', 'operator' => 'is', 'value' => 'high' }] },
              'actions' => [{ 'field' => 'assignee', 'value' => 'support_team' }]
            }
          ]
        },
        description: 'moderate configuration well within limits'
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
