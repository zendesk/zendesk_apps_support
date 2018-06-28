# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

describe ZendeskAppsSupport::Validations::Requirements do
  before do
    allow(package).to receive(:has_file?).with('requirements.json').and_return(!requirements_string.nil?)
    allow(package).to receive(:read_file).with('requirements.json') { requirements_string }
    allow(package).to receive(:manifest).and_return(manifest)
  end
  let(:dir) { Dir.mktmpdir }
  let(:requirements_string) { nil }
  let(:manifest) { ZendeskAppsSupport::Manifest.new(File.read('spec/app/manifest.json')) }
  let(:package) { ZendeskAppsSupport::Package.new(dir, false) }
  let(:errors) { ZendeskAppsSupport::Validations::Requirements.call(package) }

  context 'the file is not valid JSON' do
    let(:requirements_string) { '{' }

    it 'creates an error' do
      expect(errors.first.key).to eq(:requirements_not_json)
    end
  end

  context 'the file is valid JSON' do
    let(:requirements_string) { read_fixture_file('requirements.json') }

    it 'creates no error' do
      expect(errors).to be_empty
    end
  end

  context 'requirements-only app' do
    before do
      allow(manifest).to receive(:requirements_only?).and_return(true)
    end

    it 'creates an error when the file does not exist' do
      expect(errors.first.key).to eq(:missing_requirements)
    end
  end

  context 'marketing-only app' do
    before do
      allow(manifest).to receive(:marketing_only?).and_return(true)
    end

    let(:requirements_string) { read_fixture_file('requirements.json') }

    it 'creates an error when the file exists' do
      expect(errors.first.key).to eq(:requirements_not_supported)
    end
  end

  context 'chat-only app' do
    let(:manifest) { ZendeskAppsSupport::Manifest.new(File.read('spec/fixtures/chat_only_manifest.json')) }
    let(:requirements_string) { read_fixture_file('requirements.json') }

    it 'creates an error when the file exists' do
      expect(errors.first.key).to eq(:requirements_not_supported)
    end
  end

  context 'there are more than 10 requirements' do
    let(:requirements_string) do
      requirements_content = {}
      max = ZendeskAppsSupport::Validations::Requirements::MAX_REQUIREMENTS

      ZendeskAppsSupport::AppRequirement::TYPES.each do |type|
        requirements_content[type] = {}
        (max - 1).times { |n| requirements_content[type]["#{type}#{n}"] = { 'title' => "#{type}#{n}" } }
      end

      JSON.generate(requirements_content)
    end

    it 'creates an error' do
      expect(errors.first.key).to eq(:excessive_requirements)
    end
  end

  context 'a requirement field missing a "key"' do
    let(:requirements_string) { JSON.generate('targets' => { 'abc' => {} }) }

    it 'creates an error for missing required fields' do
      expect(errors.first.key).to eq(:missing_required_fields)
    end
  end

  context 'a user field missing a "key"' do
    let(:requirements_string) do
      JSON.generate('user_fields' => { 'abc' => { 'type' => 'text', 'title' => 'abc' } })
    end

    it 'creates an error for missing required fields' do
      expect(errors.first.key).to eq(:missing_required_fields)
    end
  end

  context 'an org field missing a "key"' do
    let(:requirements_string) do
      JSON.generate('organization_fields' => { 'abc' => { 'type' => 'text', 'title' => 'abc' } })
    end

    it 'creates an error for missing required fields' do
      expect(errors.first.key).to eq(:missing_required_fields)
    end
  end

  context 'multiple custom field types with valid fields' do
    let(:requirements_string) do
      JSON.generate(
        'user_fields' => {
          'abc' => { 'type' => 'text', 'title' => 'abc', 'key' => 'abc' }
        },
        'organization_fields' => {
          'xyz' => { 'type' => 'text', 'title' => 'xyz', 'key' => 'xyz' }
        }
      )
    end
    it 'passes with no errors' do
      puts errors
      expect(errors).to be_empty
    end
  end

  context 'multiple custom field groups with duplicate nested keys' do
    let(:requirements_string) do
      JSON.generate(
        'user_fields' => {
          'abc' => { 'type' => 'text', 'title' => 'abc' }
        },
        'organization_fields' => {
          'abc' => { 'type' => 'text', 'title' => 'abc', 'key' => 'abc' }
        }
      )
    end
    it 'create an error for missing required fields' do
      expect(errors.first.key).to eq(:missing_required_fields)
    end
  end

  context 'many requirements are lacking required fields' do
    let(:requirements_string) { JSON.generate('targets' => { 'abc' => {}, 'xyz' => {} }) }

    it 'creates an error for each of them' do
      expect(errors.size).to eq(2)
    end
  end

  context 'there are invalid requirement types' do
    let(:requirements_string) { '{ "i_am_not_a_valid_type": {}}' }

    it 'creates an error' do
      expect(errors.first.key).to eq(:invalid_requirements_types)
    end
  end

  context 'there are duplicate requirements' do
    let(:requirements_string) { '{ "a": { "b": 1, "b": 2 }}' }

    it 'creates an error' do
      expect(errors.first.key).to eq(:duplicate_requirements)
    end
  end

  context 'there are multiple channel integrations' do
    let(:requirements_string) do
      '{ "channel_integrations": { "one": { "manifest_url": "manifest"}, "two": { "manifest_url": "manifest"} }}'
    end

    it 'creates an error' do
      expect(errors.first.key).to eq(:multiple_channel_integrations)
    end
  end

  context 'a channel integration is missing a manifest' do
    let(:requirements_string) { '{ "channel_integrations": { "channel_one": {} }}' }

    it 'creates an error' do
      expect(errors.first.key).to eq(:missing_required_fields)
      expect(errors.first.data).to eq(field: 'manifest_url', identifier: 'channel_one')
    end
  end

  context 'the locations are invalid' do
    let(:manifest) { ZendeskAppsSupport::Manifest.new(File.read('spec/fixtures/invalid_location_manifest.json')) }
    let(:requirements_string) { read_fixture_file('requirements.json') }

    it 'does not return a requirements error' do
      expect(errors).to be_empty
    end
  end

  context 'there is a valid custom resources schema defined' do
    let(:requirements_string) do
      JSON.generate(
        'custom_resources_schema' => { 'resource_types': [], 'relationship_types': [] }
      )
    end

    it 'does not return an error' do
      expect(errors).to be_empty
    end
  end

  context 'a custom resources schema contains invalid keys' do
    let(:requirements_string) do
      JSON.generate(
        'custom_resources_schema' => {
          'resource_types': [], 'relationship_types': [], 'resources': [], 'relationships': []
        }
      )
    end

    it 'creates an error' do
      expect(errors.first.key).to eq(:invalid_cr_schema_keys)
      expect(errors.first.data).to eq(invalid_keys: 'resources, relationships', count: 2)
    end
  end

  context 'a custom resources schema is missing resource_types' do
    let(:requirements_string) { JSON.generate('custom_resources_schema' => { 'relationship_types': [] }) }

    it 'creates an error' do
      expect(errors.first.key).to eq(:missing_required_fields)
      expect(errors.first.data).to eq(field: 'resource_types', identifier: 'custom_resources_schema')
    end
  end

  context 'a custom resources schema is missing relationship_types' do
    let(:requirements_string) { JSON.generate('custom_resources_schema' => { 'resource_types': [] }) }

    it 'creates an error' do
      expect(errors.first.key).to eq(:missing_required_fields)
      expect(errors.first.data).to eq(field: 'relationship_types', identifier: 'custom_resources_schema')
    end
  end
end
