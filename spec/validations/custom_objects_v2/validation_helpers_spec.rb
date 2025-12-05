# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::CustomObjectsV2::ValidationHelpers do
  let(:test_class) do
    Class.new do
      class << self
        include ZendeskAppsSupport::Validations::CustomObjectsV2::ValidationHelpers

        public :extract_hash_entries, :count_conditions, :safe_value
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
end
