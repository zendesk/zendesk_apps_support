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

  context 'there are more than 10 custom objects requirements' do
    let(:requirements_string) do
      requirements_content = {
        custom_objects: {
          custom_object_types: [],
          custom_object_relationship_types: []
        }
      }
      25.times do
        requirements_content[:custom_objects][:custom_object_types] << {
          key: 'foo',
          schema: {}
        }
      end
      26.times do
        requirements_content[:custom_objects][:custom_object_relationship_types] << {
          key: 'foo',
          source: 'bar',
          target: 'baz'
        }
      end
      JSON.generate(requirements_content)
    end

    it 'creates an error' do
      expect(errors.first.key).to eq(:excessive_custom_objects_requirements)
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

  context 'there are invalid target types' do
    let(:requirements_string) do
      {
        targets: {
          http_target: {
            type: 'http_target',
            title: 'HTTP target',
            method: 'post',
            target_url: 'http://test.local',
            content_type: 'application/json'
          },
          url_target_v2: {
            type: 'url_target_v2',
            title: 'URL target v2',
            method: 'post',
            target_url: 'http://test.local',
            content_type: 'application/json'
          }
        }
      }.to_json
    end

    it 'creates an error' do
      expect(errors.first.key).to eq(:invalid_requirements_types)
      expect(errors.last.key).to eq(:invalid_requirements_types)
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

  context 'custom object requirements validations' do
    context 'there is a valid custom objects schema defined' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects' => {
            'custom_object_types' => [
              'key' => 'foo',
              'schema' => {}
            ],
            'custom_object_relationship_types' => []
          }
        )
      end

      it 'does not return an error' do
        expect(errors).to be_empty
      end
    end

    context 'a custom objects schema contains invalid type-level keys' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects' => { 'custom_object_types' => [{}], 'custom_object_relationship_types' => [] }
        )
      end

      it 'creates an error' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'key', identifier: 'custom_object_types')
      end
    end

    context 'a custom objects schema is missing custom_object_types' do
      let(:requirements_string) { JSON.generate('custom_objects' => { 'custom_object_relationship_types' => [] }) }

      it 'creates an error' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'custom_object_types', identifier: 'custom_objects')
      end
    end

    context 'a custom objects schema is missing custom_object_relationship_types' do
      let(:requirements_string) { JSON.generate('custom_objects' => { 'custom_object_types' => [] }) }

      it 'does not create an error' do
        expect(errors).to be_empty
      end
    end
  end

  context 'webhooks requirements validations' do
    context 'there is a valid webhooks schema defined' do
      let(:requirements_string) do
        JSON.generate(
          'webhooks' => {
            'my_webhook' => {
              'name' => 'Example',
              'status' => 'active',
              'endpoint' => 'https://example.com',
              'http_method' => 'POST',
              'request_format' => 'json',
            }
          }
        )
      end

      it 'does not return an error' do
        expect(errors).to be_empty
      end
    end

    context 'a webhooks schema is missing required keys' do
      let(:requirements_string) do
        JSON.generate(
          'webhooks' => {
            'my_webhook': {}
          }
        )
      end
      let(:required_keys) { [ 'name', 'status', 'endpoint', 'http_method', 'request_format' ] }

      it 'creates an error' do
        errors.each do |error|
          expect(error.key).to eq(:missing_required_fields)
          expect(required_keys).to include(error.data[:field])
        end
        expect(errors.count).to eq(required_keys.count)
      end
    end

    context 'multiple webhooks schemas are missing required keys' do
      let(:requirements_string) do
        JSON.generate(
          'webhooks' => {
            'my_webhook': {},
            'my_other_webhook': {}
          }
        )
      end
      let(:required_keys) { [ 'name', 'status', 'endpoint', 'http_method', 'request_format' ] }

      it 'creates an error' do
        errors.each do |error|
          expect(error.key).to eq(:missing_required_fields)
          expect(required_keys).to include(error.data[:field])
        end
        expect(errors.count).to eq(required_keys.count * 2)
      end
    end
  end

  context 'custom objects v2 requirements limit validations' do
    context 'when requirements does not contain custom_objects_v2 key' do
      let(:requirements_string) do
        JSON.generate(
          'targets' => {
            'my_target' => { 'title' => 'My Target' }
          }
        )
      end

      it 'does not call CustomObjectsV2 module' do
        expect(ZendeskAppsSupport::Validations::CustomObjectsV2).not_to receive(:call)
        errors
      end
    end

    context 'when there are validation errors in custom objects v2' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => Array.new(51) do |i|
              { 'key' => "object_#{i + 1}", 'title' => "Object #{i + 1}", 'title_pluralized' => "Objects #{i + 1}",
                'included_in_list_view' => true }
            end,
            'object_fields' => [],
            'object_triggers' => []
          }
        )
      end

      it 'delegates validation to CustomObjectsV2 module and returns errors' do
        expect(errors.first.key).to eq(:excessive_custom_objects_v2_requirements)
        expect(errors.first.data).to eq(max: 50, count: 51)
      end
    end

    context 'when custom objects v2 requirements are valid' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => [
              { 'key' => 'object_1', 'title' => 'Object 1', 'title_pluralized' => 'Objects 1',
                'include_in_list_view' => true }
            ],
            'object_fields' => [
              { 'key' => 'field_1', 'type' => 'text', 'title' => 'Field 1', 'object_key' => 'object_1' }
            ],
            'object_triggers' => []
          }
        )
      end

      it 'delegates validation to CustomObjectsV2 module and returns no errors' do
        cov2_errors = errors.select do |error|
          error.key.to_s.include?('custom_objects_v2') || error.key.to_s.include?('cov2')
        end
        expect(cov2_errors).to be_empty
      end
    end
  end
end
