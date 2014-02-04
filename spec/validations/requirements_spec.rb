require 'zendesk_apps_support'
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

end
