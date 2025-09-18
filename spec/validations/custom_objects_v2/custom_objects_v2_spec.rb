# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::CustomObjectsV2 do
  describe '.call' do
    [
      {
        error: :invalid_cov2_requirements_structure,
        requirements: nil,
        description: 'requirements is nil'
      },
      {
        error: :invalid_cov2_requirements_structure,
        requirements: [],
        description: 'requirements is an array'
      },
      {
        error: :empty_cov2_requirements,
        requirements: {},
        description: 'requirements is empty hash'
      },
      {
        error: :empty_cov2_requirements,
        requirements: {
          'objects' => [],
          'object_fields' => [],
          'object_triggers' => []
        },
        description: 'all cov2 arrays are empty'
      },
      {
        error: :invalid_objects_structure_in_cov2_requirements,
        requirements: {
          'objects' => {},
          'object_fields' => [{ 'key' => 'field_1', 'type' => 'text', 'title' => 'Field 1',
                                'object_key' => 'object_1' }],
          'object_triggers' => [{ 'title' => 'Trigger 1', 'object_key' => 'object_1', 'conditions' => { 'all' => [] },
                                  'actions' => [] }]
        },
        description: 'objects is not an array'
      },
      {
        error: :invalid_object_fields_structure_in_cov2_requirements,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => {},
          'object_triggers' => [{ 'title' => 'Trigger 1', 'object_key' => 'object_1', 'conditions' => { 'all' => [] },
                                  'actions' => [] }]
        },
        description: 'object_fields is not an array'
      },
      {
        error: :invalid_object_triggers_structure_in_cov2_requirements,
        requirements: {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [{ 'key' => 'field_1', 'type' => 'text', 'title' => 'Field 1',
                                'object_key' => 'object_1' }],
          'object_triggers' => {}
        },
        description: 'object_triggers is not an array'
      },
      {
        error: :excessive_cov2_payload_size,
        requirements: {
          'objects' => [
            { 'key' => 'large_obj1', 'title' => 'A' * 500_000, 'title_pluralized' => 'Large Objects 1',
              'include_in_list_view' => true },
            { 'key' => 'large_obj2', 'title' => 'A' * 500_000, 'title_pluralized' => 'Large Objects 2',
              'include_in_list_view' => true },
            { 'key' => 'large_obj3', 'title' => 'A' * 500_000, 'title_pluralized' => 'Large Objects 3',
              'include_in_list_view' => true }
          ],
          'object_fields' => [],
          'object_triggers' => []
        },
        description: 'payload exceeds size limit'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it "raises #{test_case[:error]} validation error" do
          errors = described_class.call(test_case[:requirements])
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
              'title' => 'Priority Trigger',
              'object_key' => 'ticket_object',
              'conditions' => { 'all' => [{ 'field' => 'priority', 'operator' => 'is', 'value' => 'high' }] },
              'actions' => [{ 'field' => 'status', 'value' => 'open' }]
            }
          ]
        },
        description: 'requirements are valid'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns no validation errors' do
          errors = described_class.call(test_case[:requirements])
          expect(errors).to be_empty
        end
      end
    end
  end
end
