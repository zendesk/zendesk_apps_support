require 'spec_helper'
require 'json'

describe ZendeskAppsSupport::Validations::Requirements do

  it 'creates an error when the file is not valid JSON' do
    requirements = mock('AppFile', :relative_path => 'requirements.json', :read => '{')
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :requirements_not_json
  end

  it 'creates no error when the file is valid JSON' do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => read_fixture_file('requirements.json'))
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors).to be_empty
  end

  it 'creates an error if there are more than 10 requirements' do
    requirements_content = {}
    ZendeskAppsSupport::AppRequirement::TYPES.each do |type|
      requirements_content[type] = {}
      3.times { |n| requirements_content[type]["target#{n}"] = { 'title' => "#{type}#{n}"} }
    end

    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :excessive_requirements
  end

  it 'creates an errror for any requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {} } }
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :missing_required_fields
  end

  it 'creates an errror for every requirement that is lacking required fields' do
    requirements_content = { 'targets' => { 'abc' => {}, 'xyz' => {} } }
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => JSON.generate(requirements_content))
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.size.should == 2
  end

  it 'creates an error if there are invalid requirement types' do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "i_am_not_a_valid_type": {}}')
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :invalid_requirements_types
  end

  it 'creates an error if there are duplicate requirements types' do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "a": { "b": 1, "b": 2 }}')
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :duplicate_requirements
  end

end
