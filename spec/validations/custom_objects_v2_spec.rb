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

  context 'when objects key is missing' do
    let(:custom_objects_v2_requirements) do
      {
        'object_fields' => [],
        'object_triggers' => []
      }
    end

    it 'does not return validation errors' do
      expect(errors).to be_empty
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

  context 'when objects is not an array' do
    context 'when objects is a hash' do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => {},
          'object_fields' => [],
          'object_triggers' => []
        }
      end

      it 'returns a validation error for invalid objects structure' do
        expect(errors.first.key).to eq(:invalid_objects_structure_in_cov2_requirements)
        expect(errors.first.data).to eq({})
      end
    end
  end

  context 'when object_fields is not an array' do
    context 'when object_fields is a hash' do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1', 'include_in_list_view' => true }],
          'object_fields' => {},
          'object_triggers' => []
        }
      end

      it 'returns a validation error for invalid object_fields structure' do
        expect(errors.first.key).to eq(:invalid_object_fields_structure_in_cov2_requirements)
        expect(errors.first.data).to eq({})
      end
    end
  end

  context 'when object_triggers is not an array' do
    context 'when object_triggers is a hash' do
      let(:custom_objects_v2_requirements) do
        {
          'objects' => [{ 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1', 
                          'include_in_list_view' => true }],
          'object_fields' => [],
          'object_triggers' => {}
        }
      end

      it 'returns a validation error for invalid object_triggers structure' do
        expect(errors.first.key).to eq(:invalid_object_triggers_structure_in_cov2_requirements)
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

  context 'when there are more than 100 triggers per object' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => Array.new(101) do |i|
          { 'title' => "Trigger #{i + 1}", 'object_key' => 'object_1',
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] },
            'actions' => [{ 'field' => 'status', 'value' => 'resolved' }] }
        end
      }
    end

    it 'returns a validation error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_v2_triggers)
      expect(errors.first.data).to eq(max: 20, count: 101, object_key: 'object_1')
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

  context 'when there are missing keys in the object schema' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [],
        'object_triggers' => []
      }
    end

    it 'returns a validation error for missing keys' do
      expect(errors.first.key).to eq(:missing_cov2_object_schema_key)
      expect(errors.first.data).to eq(object_key: '(undefined)', missing_key: 'key')
    end
  end

  context 'when there are missing keys in the field schema' do
    let(:custom_objects_v2_requirements) do
      {
        'objects' => [
          { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
            'include_in_list_view' => true }
        ],
        'object_fields' => [
          { 'key' => 'field_1', 'title' => 'Field 1', 'type' => 'lookup' }
        ],
        'object_triggers' => []
      }
    end

    it 'returns a validation error for missing keys' do
      expect(errors.first.key).to eq(:missing_cov2_field_schema_key)
      expect(errors.first.data).to eq(object_key: '(undefined)', field_key: 'field_1', missing_key: 'object_key')
    end
  end

  context 'when there are missing keys in the trigger schema' do
    let(:custom_objects_v2_requirements) do
      {
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
      }
    end

    it 'returns a validation error for missing keys' do
      expect(errors.first.key).to eq(:missing_cov2_trigger_schema_key)
      expect(errors.first.data).to eq(object_key: '(undefined)', trigger_title: 'Trigger 1', missing_key: 'object_key')
    end
  end

  context 'when trigger has empty conditions' do
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
            'title' => 'Empty Trigger',
            'actions' => [{ 'field' => 'status', 'value' => 'updated' }],
            'conditions' => {}
          }
        ]
      }
    end

    it 'returns a validation error for empty conditions' do
      expect(errors.first.key).to eq(:invalid_cov2_trigger_conditions_structure)
      expect(errors.first.data).to eq(trigger_title: 'Empty Trigger', object_key: 'object_1')
    end
  end

  context 'when trigger has invalid conditions structure' do
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
            'title' => 'Invalid Conditions',
            'actions' => [{ 'field' => 'status', 'value' => 'updated' }],
            'conditions' => { 'invalid_key' => [] }
          }
        ]
      }
    end

    it 'returns a validation error for invalid conditions structure' do
      expect(errors.first.key).to eq(:invalid_cov2_trigger_conditions_structure)
      expect(errors.first.data).to eq(trigger_title: 'Invalid Conditions', object_key: 'object_1')
    end
  end

  context 'when trigger has empty conditions arrays' do
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
            'title' => 'Empty Arrays',
            'actions' => [{ 'field' => 'status', 'value' => 'updated' }],
            'conditions' => { 'all' => [], 'any' => [] }
          }
        ]
      }
    end

    it 'returns a validation error for empty conditions arrays' do
      expect(errors.first.key).to eq(:empty_cov2_conditions)
      expect(errors.first.data).to eq(trigger_title: 'Empty Arrays', object_key: 'object_1')
    end
  end

  context 'when trigger has invalid actions structure' do
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
            'title' => 'Invalid Actions',
            'actions' => 'not_an_array',
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
          }
        ]
      }
    end

    it 'returns a validation error for invalid actions structure' do
      expect(errors.first.key).to eq(:invalid_cov2_trigger_actions_structure)
      expect(errors.first.data).to eq(trigger_title: 'Invalid Actions', object_key: 'object_1')
    end
  end

  context 'when trigger has empty actions array' do
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
            'title' => 'Empty Actions',
            'actions' => [],
            'conditions' => { 'all' => [{ 'field' => 'status', 'operator' => 'is', 'value' => 'open' }] }
          }
        ]
      }
    end

    it 'returns a validation error for empty actions array' do
      expect(errors.first.key).to eq(:empty_cov2_trigger_actions)
      expect(errors.first.data).to eq(trigger_title: 'Empty Actions', object_key: 'object_1')
    end
  end
end
