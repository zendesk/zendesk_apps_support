require 'spec_helper'

describe ZendeskAppsSupport::Validations::Requirements do

  it 'creates an error when the file is not valid JSON' do
    requirements = mock('AppFile', :relative_path => 'requirements.json', :read => "{")
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :requirements_not_json
  end

  it "creates no error when the file is valid JSON" do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => read_fixture_file('requirements.json'))
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    expect(errors).to be_empty
  end

  it "creates an error if there are invalid requirement types" do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "i_am_not_a_valid_type": {}}')
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :invalid_requirements_types
  end

  it "creates an error if there are duplicate requirements types" do
    requirements = mock('AppFile', :relative_path => 'requirements.json',
                                   :read => '{ "a": { "b": 1, "b": 2 }}')
    package = mock('Package', :files => [requirements])
    errors = ZendeskAppsSupport::Validations::Requirements.call(package)

    errors.first.key.should == :duplicate_requirements
  end

end
