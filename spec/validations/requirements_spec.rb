require 'spec_helper'
require 'json'

describe ZendeskAppsSupport::Validations::Requirements do
  def make_package_stub(requirements, manifest_args = {})
    requirements = JSON.generate(requirements) if requirements.is_a?(Hash)
    requirements_json = double('AppFile', relative_path: 'requirements.json', read: requirements) if requirements
    manifest = double('Manifest', { requirements_only?: false, marketing_only?: false }.update(manifest_args))
    double('Package', files: [requirements_json].compact, manifest: manifest, has_requirements?: !!requirements)
  end

  it 'creates an error when the file does not exist for requirements only apps' do
    package = make_package_stub(nil, requirements_only?: true)
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:missing_requirements)
  end

  it 'creates an error when the file exists for marketing only apps' do
    package = make_package_stub('{}', marketing_only?: true)
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:requirements_not_supported)
  end

  it 'creates an error when the file is not valid JSON' do
    package = make_package_stub('{')
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:requirements_not_json)
  end

  it 'creates no error when the file is valid JSON' do
    package = make_package_stub(read_fixture_file('requirements.json'))
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors).to be_empty
  end

  it 'creates an error if there are more than 10 requirements' do
    requirements_content = {}
    max = ZendeskAppsSupport::Validations::Requirements::MAX_REQUIREMENTS

    ZendeskAppsSupport::AppRequirement::TYPES.each do |type|
      requirements_content[type] = {}
      (max - 1).times { |n| requirements_content[type]["#{type}#{n}"] = { 'title' => "#{type}#{n}" } }
    end

    package = make_package_stub(requirements_content)
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:excessive_requirements)
  end

  it 'creates an error for any requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {} } }
    package = make_package_stub(requirements_content)
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:missing_required_fields)
  end

  it 'creates an error for every requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {}, 'xyz' => {} } }
    package = make_package_stub(requirements_content)
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.size).to eq(2)
  end

  it 'creates an error if there are invalid requirement types' do
    package = make_package_stub('{ "i_am_not_a_valid_type": {}}')
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:invalid_requirements_types)
  end

  it 'creates an error if there are duplicate requirements types' do
    package = make_package_stub('{ "a": { "b": 1, "b": 2 }}')
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:duplicate_requirements)
  end

  it 'creates an error if there are multiple channel integrations' do
    package = make_package_stub(
      '{ "channel_integrations": { "one": { "manifest_url": "manifest"}, "two": { "manifest_url": "manifest"} }}'
    )
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:multiple_channel_integrations)
  end

  it 'creates an error if a channel integration is missing a manifest' do
    package = make_package_stub('{ "channel_integrations": { "channel_one": {} }}')
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:missing_required_fields)
    expect(errors.first.data).to eq({ field: 'manifest_url', identifier: 'channel_one' })
  end
end
