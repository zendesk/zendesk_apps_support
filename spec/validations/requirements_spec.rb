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

  context 'custom objects v2 requirements validations' do
    context 'there is a valid custom objects v2 schema defined' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => {
              'my_custom_object' => {
                'key' => 'my_custom_object',
                'include_in_list_view' => true,
                'title' => 'My Custom Object',
                'title_pluralized' => 'My Custom Objects'
              }
            }
          }
        )
      end

      it 'does not return an error' do
        expect(errors).to be_empty
      end
    end

    context 'there is a valid custom objects v2 schema with object_triggers' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => {
              'my_custom_object' => {
                'key' => 'my_custom_object',
                'include_in_list_view' => true,
                'title' => 'My Custom Object',
                'title_pluralized' => 'My Custom Objects',
                'fields' => [
                  { 'key' => 'status', 'type' => 'dropdown' },
                  { 'key' => 'priority', 'type' => 'text' }
                ]
              }
            },
            'object_triggers' => {
              'my_object_trigger' => {
                'object_key' => 'my_custom_object',
                'title' => 'My Object Trigger',
                'conditions' => {
                  'all' => [
                    { 'field' => 'status' }
                  ]
                },
                'actions' => [
                  { 'field' => 'priority', 'value' => 'high' }
                ]
              }
            }
          }
        )
      end

      it 'does not return an error' do
        expect(errors).to be_empty
      end
    end

    context 'custom objects v2 with multiple valid objects' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => {
              'first_object' => {
                'key' => 'first_object',
                'include_in_list_view' => true,
                'title' => 'First Object',
                'title_pluralized' => 'First Objects'
              },
              'second_object' => {
                'key' => 'second_object',
                'include_in_list_view' => false,
                'title' => 'Second Object',
                'title_pluralized' => 'Second Objects'
              }
            }
          }
        )
      end

      it 'does not return an error' do
        expect(errors).to be_empty
      end
    end

    context 'custom objects v2 object is missing required key field' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              }
            }
          )
      end

      it 'creates an error for missing key field' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'key', identifier: 'custom_objects_v2 objects.my_custom_object')
      end
    end

    context 'custom objects v2 object is missing required include_in_list_view field' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              }
            }
          )
      end

      it 'creates an error for missing include_in_list_view field' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'include_in_list_view', identifier: 'custom_objects_v2 objects.my_custom_object')
      end
    end

    context 'custom objects v2 object is missing required title field' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title_pluralized' => 'My Custom Objects'
                }
              }
            }
          )
      end

      it 'creates an error for missing title field' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'title', identifier: 'custom_objects_v2 objects.my_custom_object')
      end
    end

    context 'custom objects v2 object is missing required title_pluralized field' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object'
                }
              }
            }
          )
      end

      it 'creates an error for missing title_pluralized field' do
        expect(errors.first.key).to eq(:missing_required_fields)
        expect(errors.first.data).to eq(field: 'title_pluralized', identifier: 'custom_objects_v2 objects.my_custom_object')
      end
    end

    context 'custom objects v2 object is missing multiple required fields' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'incomplete_object' => {
                  'include_in_list_view' => true
                }
              }
            }
          )
      end
      let(:required_keys) { ['key', 'title', 'title_pluralized'] }

      it 'creates errors for all missing fields' do
        errors.each do |error|
          expect(error.key).to eq(:missing_required_fields)
          expect(required_keys).to include(error.data[:field])
          expect(error.data[:identifier]).to eq('custom_objects_v2 objects.incomplete_object')
        end
        expect(errors.count).to eq(required_keys.count)
      end
    end

    context 'custom objects v2 object is completely empty' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'empty_object' => {}
              }
            }
          )
      end
      let(:required_keys) { ['key', 'include_in_list_view', 'title', 'title_pluralized'] }

      it 'creates errors for all required fields' do
        errors.each do |error|
          expect(error.key).to eq(:missing_required_fields)
          expect(required_keys).to include(error.data[:field])
          expect(error.data[:identifier]).to eq('custom_objects_v2 objects.empty_object')
        end
        expect(errors.count).to eq(required_keys.count)
      end
    end

    context 'multiple custom objects v2 objects with missing fields' do
      let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'first_incomplete' => {
                  'include_in_list_view' => true
                },
                'second_incomplete' => {
                  'key' => 'second_incomplete'
                }
              }
            }
          )
      end

      it 'creates errors for missing fields in both objects' do
        # First object missing: key, title, title_pluralized
        first_object_errors = errors.select { |e| e.data[:identifier] == 'custom_objects_v2 objects.first_incomplete' }
        expect(first_object_errors.count).to eq(3)
        first_object_missing_fields = first_object_errors.map { |e| e.data[:field] }
        expect(first_object_missing_fields).to include('key', 'title', 'title_pluralized')

        # Second object missing: include_in_list_view, title, title_pluralized
        second_object_errors = errors.select { |e| e.data[:identifier] == 'custom_objects_v2 objects.second_incomplete' }
        expect(second_object_errors.count).to eq(3)
        second_object_missing_fields = second_object_errors.map { |e| e.data[:field] }
        expect(second_object_missing_fields).to include('include_in_list_view', 'title', 'title_pluralized')

        expect(errors.count).to eq(6)
      end
    end

    context 'custom objects v2 schema has no objects array' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {}
        )
      end

      it 'does not create any validation errors' do
        expect(errors).to be_empty
      end
    end

    context 'custom objects v2 schema has empty objects hash' do
      let(:requirements_string) do
        JSON.generate(
          'custom_objects_v2' => {
            'objects' => {}
          }
        )
      end

      it 'does not create any validation errors' do
        expect(errors).to be_empty
      end
    end

    context 'no custom objects v2 requirements are present' do
      let(:requirements_string) do
        JSON.generate(
          'targets' => {
            'my_target' => {
              'title' => 'My Target',
              'type' => 'email_target'
            }
          }
        )
      end

      it 'does not create any custom objects v2 validation errors' do
        expect(errors).to be_empty
      end
    end

    context 'object_triggers validation' do
      context 'object_triggers missing required object_key field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => [
                      { 'field' => 'status' }
                    ]
                  },
                  'actions' => [
                    { 'field' => 'status', 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for missing object_key field' do
          expect(errors.first.key).to eq(:missing_required_fields)
          expect(errors.first.data).to eq(field: 'object_key', identifier: 'object_triggers.my_trigger')
        end
      end

      context 'object_triggers missing required title field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'conditions' => {
                    'all' => [
                      { 'field' => 'status' }
                    ]
                  },
                  'actions' => [
                    { 'field' => 'status', 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for missing title field' do
          expect(errors.first.key).to eq(:missing_required_fields)
          expect(errors.first.data).to eq(field: 'title', identifier: 'object_triggers.my_trigger')
        end
      end

      context 'object_triggers missing required conditions field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'actions' => [
                    { 'field' => 'status', 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for missing conditions field' do
          expect(errors.first.key).to eq(:missing_required_fields)
          expect(errors.first.data).to eq(field: 'conditions', identifier: 'object_triggers.my_trigger')
        end
      end

      context 'object_triggers missing required actions field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => [
                      { 'field' => 'status' }
                    ]
                  }
                }
              }
            }
          )
        end

        it 'creates an error for missing actions field' do
          expect(errors.first.key).to eq(:missing_required_fields)
          expect(errors.first.data).to eq(field: 'actions', identifier: 'object_triggers.my_trigger')
        end
      end

      context 'object_triggers with action missing field key' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => []
                  },
                  'actions' => [
                    { 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for action missing field key' do
          error = errors.find { |e| e.data[:identifier] == 'object_triggers.my_trigger.actions[0]' && e.data[:field] == 'field' }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
        end
      end

      context 'object_triggers with action missing value key' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => []
                  },
                  'actions' => [
                    { 'field' => 'status' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for action missing value key' do
          error = errors.find { |e| e.data[:identifier] == 'object_triggers.my_trigger.actions[0]' && e.data[:field] == 'value' }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
        end
      end

      context 'object_triggers with conditions.all not being an array' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => 'not_an_array'
                  },
                  'actions' => []
                }
              }
            }
          )
        end

        it 'creates an error for conditions.all not being an array' do
          error = errors.find { |e| e.data[:field] == 'conditions.all (must be array)' }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
          expect(error.data[:identifier]).to eq('object_triggers.my_trigger')
        end
      end

      context 'object_triggers with condition missing field key' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => [
                      { 'operator' => 'equals' }
                    ]
                  },
                  'actions' => []
                }
              }
            }
          )
        end

        it 'creates an error for condition missing field key' do
          error = errors.find { |e| e.data[:identifier] == 'object_triggers.my_trigger.conditions.all[0]' && e.data[:field] == 'field' }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
        end
      end

      context 'object_triggers with condition field referencing non-existent object field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'my_custom_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => [
                      { 'field' => 'nonexistent_field' }
                    ]
                  },
                  'actions' => [
                    { 'field' => 'status', 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for invalid field reference' do
          error = errors.find { |e| e.data[:identifier] == 'object_triggers.my_trigger.conditions.all[0]' }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
          expect(error.data[:field]).to include('nonexistent_field')
          expect(error.data[:field]).to include('status')
        end
      end

      context 'object_triggers with invalid object_key reference' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'my_custom_object',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects',
                  'fields' => [
                    { 'key' => 'status', 'type' => 'dropdown' }
                  ]
                }
              },
              'object_triggers' => {
                'my_trigger' => {
                  'object_key' => 'nonexistent_object',
                  'title' => 'My Trigger',
                  'conditions' => {
                    'all' => [
                      { 'field' => 'status' }
                    ]
                  },
                  'actions' => [
                    { 'field' => 'status', 'value' => 'open' }
                  ]
                }
              }
            }
          )
        end

        it 'creates an error for invalid object_key reference' do
          error = errors.find { |e| e.data[:identifier] == 'object_triggers.my_trigger' && e.data[:field].include?('object_key') }
          expect(error).not_to be_nil
          expect(error.key).to eq(:missing_required_fields)
          expect(error.data[:field]).to include('nonexistent_object')
          expect(error.data[:field]).to include('my_custom_object')
        end
      end
    end

    context 'custom object key mismatch validation' do
      context 'object key does not match its internal key field' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'my_custom_object' => {
                  'key' => 'different_key',
                  'include_in_list_view' => true,
                  'title' => 'My Custom Object',
                  'title_pluralized' => 'My Custom Objects'
                }
              }
            }
          )
        end

        it 'creates an error for key mismatch' do
          expect(errors.first.key).to eq(:custom_object_key_mismatch)
          expect(errors.first.data).to eq(object_name: 'my_custom_object', expected_key: 'my_custom_object', actual_key: 'different_key')
        end
      end

      context 'multiple objects with key mismatches' do
        let(:requirements_string) do
          JSON.generate(
            'custom_objects_v2' => {
              'objects' => {
                'first_object' => {
                  'key' => 'wrong_first_key',
                  'include_in_list_view' => true,
                  'title' => 'First Object',
                  'title_pluralized' => 'First Objects'
                },
                'second_object' => {
                  'key' => 'wrong_second_key',
                  'include_in_list_view' => false,
                  'title' => 'Second Object',
                  'title_pluralized' => 'Second Objects'
                }
              }
            }
          )
        end

        it 'creates errors for both key mismatches' do
          mismatch_errors = errors.select { |e| e.key == :custom_object_key_mismatch }
          expect(mismatch_errors.count).to eq(2)

          first_error = mismatch_errors.find { |e| e.data[:object_name] == 'first_object' }
          expect(first_error.data).to eq(object_name: 'first_object', expected_key: 'first_object', actual_key: 'wrong_first_key')

          second_error = mismatch_errors.find { |e| e.data[:object_name] == 'second_object' }
          expect(second_error.data).to eq(object_name: 'second_object', expected_key: 'second_object', actual_key: 'wrong_second_key')
        end
      end
    end
  end
end
