require 'spec_helper'
require 'json'

describe ZendeskAppsSupport::Validations::Requirements do

  it 'creates an error when the file is not valid JSON' do
    requirements = double('AppFile', :relative_path => 'requirements.json', :read => '{')
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:requirements_not_json)
  end

  it 'creates no error when the file is valid JSON' do
    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => read_fixture_file('requirements.json'))
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors).to be_empty
  end

  it 'creates an error if there are more than 10 requirements' do
    requirements_content = {}
    max = ZendeskAppsSupport::Validations::Requirements::MAX_REQUIREMENTS

    ZendeskAppsSupport::AppRequirement::TYPES.each do |type|
      requirements_content[type] = {}
      (max - 1).times { |n| requirements_content[type]["#{type}#{n}"] = { 'title' => "#{type}#{n}"} }
    end

    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:excessive_requirements)
  end

  it 'creates an errror for any requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {} } }
    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:missing_required_fields)
  end

  it 'creates an errror for every requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {}, 'xyz' => {} } }
    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.size).to eq(2)
  end

  it 'creates an error if there are invalid requirement types' do
    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "i_am_not_a_valid_type": {}}')
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:invalid_requirements_types)
  end

  it 'creates an error if there are duplicate requirements types' do
    requirements = double('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "a": { "b": 1, "b": 2 }}')
    package = double('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors.first.key).to eq(:duplicate_requirements)
  end

end
