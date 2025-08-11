# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe ZendeskAppsSupport::Validations::CustomObjectsV2 do
  let(:custom_objects_v2_requirements) { nil }
  let(:errors) { described_class.call(custom_objects_v2_requirements) }

  context 'when custom objects v2 requirements is not a hash' do
    let(:custom_objects_v2_requirements) { [] }

    it 'returns a validation error for invalid structure' do
      expect(errors.first.key).to eq(:invalid_cov2_requirements_structure)
      expect(errors.first.data).to eq({})
    end
  end

  context 'when custom objects v2 requirements is empty hash' do
    let(:custom_objects_v2_requirements) { {} }

    it 'returns a validation error for empty requirements' do
      expect(errors.first.key).to eq(:empty_cov2_requirements)
      expect(errors.first.data).to eq({})
    end
  end

  context 'when objects, object_fields, and object_triggers arrays are empty' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [],
        'object_fields' => [],
        'object_triggers' => []
      }
    end

    it 'returns a validation error for empty requirements' do
      expect(errors.first.key).to eq(:empty_cov2_requirements)
      expect(errors.first.data).to eq({})
    end
  end

  [
    { field: 'objects', value: {}, error: :invalid_objects_structure_in_cov2_requirements },
    { field: 'object_fields', value: {}, error: :invalid_object_fields_structure_in_cov2_requirements },
    { field: 'object_triggers', value: {}, error: :invalid_object_triggers_structure_in_cov2_requirements }
  ].each do |test_case|
    context "when #{test_case[:field]} is not an array" do
      let(:custom_objects_v2_requirements) do
        base_requirements = {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                          'include_in_list_view' => true }],
          'object_fields' => [{ 'key' => 'field_1', 'type' => 'text', 'title' => 'Field 1',
                                'object_key' => 'object_1' }],
          'object_triggers' => [{ 'title' => 'Trigger 1', 'object_key' => 'object_1',
                                  'conditions' => {
                                    'all' => [
                                      { 'field' => 'status', 'operator' => 'is', 'value' => 'open' }
                                    ]
                                  },
                                  'actions' => [{ 'field' => 'status', 'value' => 'resolved' }] }]
        }
        base_requirements[test_case[:field]] = test_case[:value]
        base_requirements
      end

      it "returns a validation error for invalid #{test_case[:field]} structure" do
        expect(errors.first.key).to eq(test_case[:error])
        expect(errors.first.data).to eq({})
      end
    end
  end

  context 'when there are more than 50 custom objects' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => Array.new(51) do |i|
          { 'key' => "object_#{i + 1}", 'title' => "Object #{i + 1}", 'title_pluralized' => "Objects #{i + 1}",
            'include_in_list_view' => true }
        end,
        'object_fields' => [],
        'object_triggers' => []
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_requirements)
      expect(errors.first.data).to eq(max: 50, count: 51)
    end
  end

  context 'when there are more than 10 fields per object' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => Array.new(11) do |i|
          { 'key' => "field_#{i + 1}", 'type' => 'text', 'title' => "Field #{i + 1}", 'object_key' => 'object_1' }
        end,
        'object_triggers' => []
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_fields)
      expect(errors.first.data).to eq(max: 10, count: 11, object_key: 'object_1')
    end
  end

  context 'when there are more than 20 triggers per object' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => Array.new(21) do |i|
          { 'title' => "Trigger #{i + 1}", 'object_key' => 'object_1',
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] },
            'actions' => [{ 'field' => 'status', 'value' => 'resolved' }] }
        end
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_triggers)
      expect(errors.first.data).to eq(max: 20, count: 21, object_key: 'object_1')
    end
  end

  context 'when there are more than 25 actions per trigger' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => [
          {
            'title' => 'Trigger 1',
            'object_key' => 'object_1',
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] },
            'actions' => Array.new(26) do |i|
              { 'field' => "field_#{i + 1}", 'value' => "value_#{i + 1}" }
            end
          }
        ]
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_trigger_actions)
      expect(errors.first.data).to eq(max: 25, count: 26, trigger_title: 'Trigger 1')
    end
  end

  context 'when there are more than 50 conditions combined(all+any) in trigger' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => [
          {
            'title' => 'Trigger 1',
            'object_key' => 'object_1',
            'conditions' => {
              'all' => Array.new(30) do |i|
                { 'field' => "field_all_#{i + 1}", 'operator' => 'is', 'value' => "value_#{i + 1}" }
              end,
              'any' => Array.new(25) do |i|
                { 'field' => "field_any_#{i + 1}", 'operator' => 'is', 'value' => "value_#{i + 1}" }
              end
            },
            'actions' => [{ 'field' => 'status', 'value' => 'resolved' }]
          }
        ]
      }
    end

    it 'returns a validation error with combined count' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_trigger_conditions)
      expect(errors.first.data).to eq(max: 50, count: 55, trigger_title: 'Trigger 1')
    end
  end

  shared_examples_for 'exceeding field type limits per object' do |field_type|
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => Array.new(6) do |i|
          { 'key' => "field_#{i + 1}", 'type' => field_type, 'title' => "Field #{i + 1}", 'object_key' => 'object_1',
            'custom_field_options' => [{ 'name' => 'open', 'value' => 'open' }] }
        end,
        'object_triggers' => []
      }
    end

    it 'returns a validation error' do
      expected_error_key = :excessive_cov2_selection_fields_per_object
      expect(errors.first.key).to eq(expected_error_key)
      expect(errors.first.data).to eq(max: 5, count: 6, object_key: 'object_1', field_type: field_type)
    end
  end

  context 'when there are more than 5 dropdown fields per object' do
    it_behaves_like 'exceeding field type limits per object', 'dropdown'
  end

  context 'when there are more than 5 multiselect fields per object' do
    it_behaves_like 'exceeding field type limits per object', 'multiselect'
  end

  shared_examples_for 'exceeding field option limits per field' do |field_type|
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [
          { 'key' => 'field_1', 'type' => field_type, 'title' => 'Field 1', 'object_key' => 'object_1',
            'custom_field_options' => Array.new(11) do |i|
              { 'name' => "Option #{i + 1}", 'value' => "Value #{i + 1}" }
            end }
        ],
        'object_triggers' => []
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_cov2_field_options)
      expect(errors.first.data).to eq(max: 10, count: 11, field_key: 'field_1', object_key: 'object_1')
    end
  end

  context 'when there are more than 10 options for a dropdown field' do
    it_behaves_like 'exceeding field option limits per field', 'dropdown'
  end

  context 'when there are more than 10 options for a multiselect field' do
    it_behaves_like 'exceeding field option limits per field', 'multiselect'
  end

  context 'when there are more than 20 conditions in a relationship filter per field' do
    context 'when relationship filter conditions exceed the limit' do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => [
            { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true }
          ],
          'object_fields' => [
            { 'key' => 'field_1', 'type' => 'lookup', 'title' => 'Field 1', 'object_key' => 'object_1',
              'relationship_target' => 'zen:ticket',
              'relationship_filter' => {
                'all' => Array.new(15) do |i|
                  { 'field' => "all_field_#{i + 1}", 'operator' => 'is', 'value' => "value_#{i + 1}" }
                end,
                'any' => Array.new(10) do |i|
                  { 'field' => "any_field_#{i + 1}", 'operator' => 'is', 'value' => "value_#{i + 1}" }
                end
              } }
          ],
          'object_triggers' => []
        }
      end

      it 'returns a validation error for combined all+any conditions exceeding limit' do
        expect(errors.first.key).to eq(:excessive_cov2_relationship_filter_conditions)
        expect(errors.first.data).to eq(max: 20, count: 25, field_key: 'field_1', object_key: 'object_1')
      end
    end
  end

  [
    {
      description: 'object schema',
      requirements: {
        'objects' => [
          { 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => []
      },
      error_key: :missing_cov2_object_schema_key,
      error_data: { object_key: '(undefined)', missing_key: 'key' }
    },
    {
      description: 'field schema',
      requirements: {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [
          { 'key' => 'field_1', 'title' => 'Field 1', 'type' => 'lookup' }
        ],
        'object_triggers' => []
      },
      error_key: :missing_cov2_field_schema_key,
      error_data: { object_key: '(undefined)', field_key: 'field_1', missing_key: 'object_key' }
    },
    {
      description: 'trigger schema',
      requirements: {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [
          { 'key' => 'field_1', 'title' => 'Field 1', 'type' => 'lookup', 'object_key' => 'object_1' }
        ],
        'object_triggers' => [
          { 'title' => 'Trigger 1', 'conditions' => [], 'actions' => [] }
        ]
      },
      error_key: :missing_cov2_trigger_schema_key,
      error_data: { object_key: '(undefined)', trigger_title: 'Trigger 1', missing_key: 'object_key' }
    }
  ].each do |test_case|
    context "when there are missing keys in the #{test_case[:description]}" do
      let(:custom_objects_v2_requirements) { test_case[:requirements] }

      it 'returns a validation error for missing keys' do
        expect(errors.first.key).to eq(test_case[:error_key])
        expect(errors.first.data).to eq(test_case[:error_data])
      end
    end
  end

  [
    {
      title: 'Empty Trigger',
      conditions: {},
      error: :invalid_cov2_trigger_conditions_structure,
      description: 'empty conditions'
    },
    {
      title: 'Invalid Conditions',
      conditions: { 'invalid_key' => [] },
      error: :invalid_cov2_trigger_conditions_structure,
      description: 'invalid conditions structure'
    },
    {
      title: 'Empty Arrays',
      conditions: { 'all' => [], 'any' => [] },
      error: :empty_cov2_trigger_conditions,
      description: 'empty conditions arrays'
    }
  ].each do |test_case|
    context "when trigger has #{test_case[:description]}" do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => [
            { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true }
          ],
          'object_fields' => [],
          'object_triggers' => [
            {
              'object_key' => 'object_1',
              'title' => test_case[:title],
              'actions' => [{ 'field' => 'status', 'value' => 'updated' }],
              'conditions' => test_case[:conditions]
            }
          ]
        }
      end

      it "returns a validation error for #{test_case[:description]}" do
        expect(errors.first.key).to eq(test_case[:error])
        expect(errors.first.data).to eq(trigger_title: test_case[:title], object_key: 'object_1')
      end
    end
  end

  [
    {
      title: 'Invalid Actions',
      actions: 'not_an_array',
      error: :invalid_cov2_trigger_actions_structure,
      description: 'invalid actions structure'
    },
    {
      title: 'Empty Actions',
      actions: [],
      error: :empty_cov2_trigger_actions,
      description: 'empty actions array'
    }
  ].each do |test_case|
    context "when trigger has #{test_case[:description]}" do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => [
            { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
              'include_in_list_view' => true }
          ],
          'object_fields' => [],
          'object_triggers' => [
            {
              'object_key' => 'object_1',
              'title' => test_case[:title],
              'actions' => test_case[:actions],
              'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
            }
          ]
        }
      end

      it "returns a validation error for #{test_case[:description]}" do
        expect(errors.first.key).to eq(test_case[:error])
        expect(errors.first.data).to eq(trigger_title: test_case[:title], object_key: 'object_1')
      end
    end
  end

  context 'when payload exceeds 1MB limit' do
    let(:large_string) { 'A' * 500_000 } # 500KB string
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'large_obj1', 'title' => large_string, 'title_pluralized' => 'Large Objects 1',
            'include_in_list_view' => true },
          { 'key' => 'large_obj2', 'title' => large_string, 'title_pluralized' => 'Large Objects 2',
            'include_in_list_view' => true },
          { 'key' => 'large_obj3', 'title' => large_string, 'title_pluralized' => 'Large Objects 3',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => []
      }
    end

    it 'returns a payload size validation error and skips other validations' do
      expect(errors.size).to eq(1)
      expect(errors.first.key).to eq(:excessive_cov2_payload_size)
      expect(errors.first.data).to eq({})
    end
  end
end
