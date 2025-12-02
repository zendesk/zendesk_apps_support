# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::CustomObjectsV2::ValidationHelpers do
  let(:test_class) do
    Class.new do
      class << self
        include ZendeskAppsSupport::Validations::CustomObjectsV2::ValidationHelpers

        public :extract_hash_entries, :count_conditions, :safe_value, :contains_setting_placeholder?
      end
    end
  end

  describe '.extract_hash_entries' do
    [
      {
        input: nil,
        expected: [],
        description: 'collection is nil or empty'
      },
      {
        input: [{ key: 'value1' }, 'string', { key: 'value2' }, 123],
        expected: [{ key: 'value1' }, { key: 'value2' }],
        description: 'collection contains mixed types'
      },
      {
        input: [{ key: 'value1' }, { key: 'value2' }],
        expected: [{ key: 'value1' }, { key: 'value2' }],
        description: 'collection contains only hashes'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns expected result' do
          expect(test_class.extract_hash_entries(test_case[:input])).to eq(test_case[:expected])
        end
      end
    end
  end

  describe '.count_conditions' do
    [
      {
        input: nil,
        expected: 0,
        description: 'conditions is nil or invalid type'
      },
      {
        input: {},
        expected: 0,
        description: 'conditions is empty hash'
      },
      {
        input: { 'all' => [{ field: 'status' }, { field: 'priority' }] },
        expected: 2,
        description: 'conditions has valid key with items'
      },
      {
        input: { 'all' => [{ field: 'status' }], 'any' => [{ field: 'priority' }, { field: 'category' }] },
        expected: 3,
        description: 'conditions has multiple valid keys'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns expected result' do
          expect(test_class.count_conditions(test_case[:input])).to eq(test_case[:expected])
        end
      end
    end
  end

  describe '.safe_value' do
    [
      {
        input: nil,
        expected: '(undefined)',
        description: 'value is nil'
      },
      {
        input: 'valid_key',
        expected: 'valid_key',
        description: 'value is not nil'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns expected result' do
          expect(test_class.safe_value(test_case[:input])).to eq(test_case[:expected])
        end
      end
    end
  end

  describe '.contains_setting_placeholder?' do
    [
      {
        input: 'This is a string with {{ setting.some_key }} placeholder.',
        expected: true,
        description: 'string contains a valid setting placeholder with underscores'
      },
      {
        input: 'Text with {{ setting.some.nested.key }} placeholder.',
        expected: true,
        description: 'string contains a setting placeholder with dots'
      },
      {
        input: 'Text with {{ setting.some-key }} placeholder.',
        expected: true,
        description: 'string contains a setting placeholder with hyphens'
      },
      {
        input: 'Text with {{setting.key}} placeholder.',
        expected: true,
        description: 'string contains a setting placeholder without spaces'
      },
      {
        input: 'Text with {{  setting.key  }} placeholder.',
        expected: true,
        description: 'string contains a setting placeholder with multiple spaces'
      },
      {
        input: 'This string has no placeholders.',
        expected: false,
        description: 'string does not contain any placeholders'
      },
      {
        input: '{{ setting }}',
        expected: false,
        description: 'string contains invalid placeholder without dot notation'
      },
      {
        input: 12_345,
        expected: false,
        description: 'input is not a string'
      },
      {
        input: nil,
        expected: false,
        description: 'input is nil'
      }
    ].each do |test_case|
      context "when #{test_case[:description]}" do
        it 'returns expected result' do
          expect(test_class.contains_setting_placeholder?(test_case[:input])).to eq(test_case[:expected])
        end
      end
    end
  end
end
