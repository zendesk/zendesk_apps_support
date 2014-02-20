require 'spec_helper'

describe ZendeskAppsSupport::Validations::Manifest do

  def default_required_params(overrides = {})
    valid_fields = ZendeskAppsSupport::Validations::Manifest::REQUIRED_MANIFEST_FIELDS.inject({ :frameworkVersion => '1.0' }) do |fields, name|
      fields[name] = name
      fields
    end

    valid_fields.merge(overrides)
  end

  def create_package(parameter_hash)
    params = default_required_params(parameter_hash)
    @manifest.stub(:read => MultiJson.dump(params))
    @package
  end

  def manifest_error(package)
    errors = ZendeskAppsSupport::Validations::Manifest.call(package)

    errors.map(&:to_s)
  end

  it 'should have an error when manifest.json is missing' do
    files = [mock('AppFile', :relative_path => 'abc.json')]
    package = mock('Package', :files => files)
    manifest_error(package).should have_error 'Could not find manifest.json'
  end

  before do
    @manifest = mock('AppFile', :relative_path => 'manifest.json', :read => "{}")
    @package = mock('Package', :files => [@manifest],
      :has_location? => true, :has_js? => true, :is_requirements_only? => false, :requirements_only= => nil)
  end

  subject { manifest_error(@package) }

  RSpec::Matchers.define :have_error do |error|
    match do |errors|
      errors.include? error
    end
  end

  it 'should have an error when required field is missing' do
    subject.should have_error 'Missing required fields in manifest: author, defaultLocale'
  end

  it 'should have an error when location is missing without requirements' do
    @package.stub(:has_location? => false)
    subject.should have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when location is defined but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true, :location => 1))
    subject.should have_error 'Having location defined while requirements only is true'
  end

  it 'should not have an error when location is missing but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true))
    @package.stub(:has_location? => false)
    subject.should_not have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when frameworkVersion is missing without requirements' do
    subject.should have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when frameworkVersion is defined but requirements only is true' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true, :frameworkVersion => 1))
    subject.should have_error 'Having framework version defined while requirements only is true'
  end

  it 'should not have an error when frameworkVersion is missing with requirements' do
    @manifest.stub(:read => MultiJson.dump(:requirementsOnly => true))
    subject.should_not have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when the defaultLocale is invalid' do
    manifest = { 'defaultLocale' => 'pt-BR-1' }
    @manifest.stub(:read => MultiJson.dump(manifest))

    subject.find { |e| e =~ /default locale/ }.should_not be_nil
  end

  it 'should have an error when the translation file is missing for the defaultLocale' do
    manifest = { 'defaultLocale' => 'pt' }
    @manifest.stub(:read => MultiJson.dump(manifest))
    translation_files = mock('AppFile', :relative_path => 'translations/en.json')
    @package.stub(:translation_files => [translation_files])

    subject.find { |e| e =~ /Missing translation file/ }.should_not be_nil
  end

  it 'should have an error when the location is invalid' do
    manifest = { 'location' => ['ticket_sidebar', 'a_invalid_location'] }
    @manifest.stub(:read => MultiJson.dump(manifest))

    subject.find { |e| e =~ /invalid location/ }.should_not be_nil
  end

  it 'should have an error when there are duplicate locations' do
    manifest = { 'location' => ['ticket_sidebar', 'ticket_sidebar'] }
    @manifest.stub(:read => MultiJson.dump(manifest))

    subject.find { |e| e =~ /duplicate/ }.should_not be_nil
  end

  it 'should have an error when the version is not supported' do
    manifest = { 'frameworkVersion' => '0.7' }
    @manifest.stub(:read => MultiJson.dump(manifest))

    subject.find { |e| e =~ /not a valid framework version/ }.should_not be_nil
  end

  it 'should have an error when a hidden parameter is set to required' do
    manifest = {
      'parameters' => [
        'name'     => 'a parameter',
        'type'     => 'hidden',
        'required' => true
      ]
    }

    @manifest.stub(:read => MultiJson.dump(manifest))

    manifest_error(@package).find { |e| e =~ /set to hidden and cannot be required/ }.should_not be_nil
  end

  it 'should have an error when manifest is not a valid json' do
    manifest = mock('AppFile', :relative_path => 'manifest.json', :read => "}")
    @package.stub(:files => [manifest])
    errors = ZendeskAppsSupport::Validations::Manifest.call(@package)

    errors.first.to_s.should =~ /^manifest is not proper JSON/
  end

  it "should have an error when required oauth fields are missing" do
    oauth_hash = {
      "oauth" => {}
    }
    errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(default_required_params.merge(oauth_hash)))
    oauth_error = errors.find { |e| e.to_s =~ /oauth field/ }
    oauth_error.to_s.should == "Missing required oauth fields in manifest: client_id, client_secret, authorize_uri, access_token_uri"
  end

  context 'with invalid parameters' do

    before do
      ZendeskAppsSupport::Validations::Manifest.stub(:default_locale_error)
      ZendeskAppsSupport::Validations::Manifest.stub(:invalid_location_error)
      ZendeskAppsSupport::Validations::Manifest.stub(:invalid_version_error)
    end

    it 'has an error when the app parameters are not an array' do
      parameter_hash = {
          'parameters' => {
              'name' => 'a parameter',
              'type' => 'text'
          }
      }

      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(parameter_hash))
      errors.map(&:to_s).should have_error 'App parameters must be an array.'
    end

    it 'has an error when there is a parameter called "name"' do
      parameter_hash = {
          'parameters' => [{
              'name' => 'name',
              'type' => 'text'
          }]
      }

      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(parameter_hash))
      errors.map(&:to_s).should have_error "Can't call a parameter 'name'"
    end

    it "doesn't have an error with an array of app parameters" do
      parameter_hash = {
          'parameters' => [{
              'name' => 'a parameter',
              'type' => 'text'
          }]
      }

      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(parameter_hash))
      errors.should be_empty
    end

    it 'behaves when the manifest does not have parameters' do
      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(default_required_params))
      errors.should be_empty
    end

    it 'shows error when duplicate parameters are defined' do
      parameter_hash = {
        'parameters' => [
          {
            'name' => 'url',
            'type' => 'text'
          },
          {
            'name' => 'url',
            'type' => 'text'
          }
        ]
      }

      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(parameter_hash))
      errors.map(&:to_s).should have_error 'Duplicate app parameters defined: ["url"]'
    end

    it 'has an error when the parameter type is not valid' do
      parameter_hash = {
        'parameters' =>
        [
         {
           'name' => 'should be number',
           'type' => 'integer'
         }
        ]
      }
      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(default_required_params.merge(parameter_hash)))

      expect(errors.count).to eq 1
      expect(errors.first.to_s).to eq "integer is an invalid parameter type."
    end

    it "doesn't have an error with a correct parameter type" do
      parameter_hash = {
        'parameters' =>
        [
         {
           'name' => 'valid type',
           'type' => 'number'
         }
        ]
      }
      errors = ZendeskAppsSupport::Validations::Manifest.call(create_package(default_required_params.merge(parameter_hash)))
      expect(errors).to be_empty
    end
  end
end
