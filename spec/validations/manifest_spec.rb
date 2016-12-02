require 'spec_helper'
require 'tmpdir'

describe ZendeskAppsSupport::Validations::Manifest do
  def default_required_params(overrides = {})
    valid_fields = ZendeskAppsSupport::Validations::Manifest::REQUIRED_MANIFEST_FIELDS.values.each_with_object(frameworkVersion: '1.0') do |fields, name|
      name[fields] = fields
      name
    end

    valid_fields.merge(location: 'ticket_sidebar').merge(overrides)
  end

  def create_package(parameter_hash)
    @manifest_hash = default_required_params(parameter_hash)
    @package
  end

  RSpec::Matchers.define :have_error do |error|
    match do |package|
      errors = ZendeskAppsSupport::Validations::Manifest.call(package)
      errors.map!(&:to_s) unless error.is_a? Symbol
      @actual = errors.compact

      error ||= /.+?/

      if error.is_a? Symbol
        errors.find { |e| e.key == error }
      elsif error.is_a? String
        errors.include? error
      elsif error.is_a? Regexp
        errors.find { |e| e =~ error }
      end
    end
    diffable
  end

  let(:location) { {} }

  it 'should have an error when manifest.json is missing' do
    package = ZendeskAppsSupport::Package.new(@dir)
    allow(@package).to receive(:has_file?).with('manifest.json') { false }
    expect(package).to have_error 'Could not find manifest.json'
  end

  let(:manifest) { ZendeskAppsSupport::Manifest.new(JSON.dump(@manifest_hash)) }

  before do
    @manifest_hash = {}
    @dir = Dir.mktmpdir
    @package = ZendeskAppsSupport::Package.new(@dir, false)
    allow(@package).to receive(:has_file?) { |file| file == 'manifest.json' ? true : false }
    allow(@package).to receive(:has_location?) { true }
    allow(@package).to receive(:requirements_only) { false }
    allow(@package).to receive(:requirements_only=) { nil }
    allow(@package).to receive(:manifest) { manifest }
  end

  after do
    FileUtils.remove_entry @dir
  end

  it 'should have an error when required field is missing' do
    expect(@package).to have_error 'Missing required fields in manifest: author, defaultLocale'
  end

  it 'should have an error when location is missing without requirements' do
    allow(@package.manifest).to receive(:location?) { false }
    expect(@package).to have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when location is defined but requirements only is true' do
    @manifest_hash = { requirementsOnly: true, location: 'thicket_sidecar' }
    expect(@package).to have_error :no_location_required
  end

  it 'should not have an error when location is missing but requirements only is true' do
    @manifest_hash = { requirementsOnly: true }
    allow(@package).to receive_messages(has_location?: false)
    expect(@package).not_to have_error 'Missing required field in manifest: location'
  end

  it 'should have an error when frameworkVersion is missing without requirements' do
    expect(@package).to have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when frameworkVersion is defined but requirements only is true' do
    @manifest_hash = { requirementsOnly: true, frameworkVersion: 1 }
    expect(@package).to have_error :no_framework_version_required
  end

  it 'should not have an error when frameworkVersion is missing with requirements' do
    @manifest_hash = { requirementsOnly: true }
    expect(@package).not_to have_error 'Missing required field in manifest: frameworkVersion'
  end

  it 'should have an error when the defaultLocale is invalid' do
    @manifest_hash = { 'defaultLocale' => 'pt-BR-1' }

    expect(@package).to have_error(/default locale/)
  end

  it 'should have an error when the translation file is missing for the defaultLocale' do
    @manifest_hash = { 'defaultLocale' => 'pt' }
    translation_files = double('AppFile', relative_path: 'translations/en.json')
    allow(@package).to receive_messages(translation_files: [translation_files])

    expect(@package).to have_error(/Missing translation file/)
  end

  context 'with a marketing only app' do
    it 'should not have any errors' do
      @package = ZendeskAppsSupport::Package.new('spec/fixtures/marketing_only_app')
      errors = ZendeskAppsSupport::Validations::Manifest.call(@package)
      expect(errors).to be_empty
    end

    it 'should have an error when parameters are specified' do
      @manifest_hash = {
        marketingOnly: true,
        parameters: [
          'name' => 'foo'
        ]
      }
      expect(@package).to have_error /Parameters can't be defined/
    end
  end

  context 'when app host is valid' do
    before do
      @manifest_hash = { 'location' => { 'zopim' => { 'chat_sidebar' => 'https://zen.desk/apps' } } }
    end
    it 'should not have an error' do
      expect(@package).not_to have_error(/invalid host/)
      expect(@package).not_to have_error(/invalid location in/)
    end
  end

  context 'app host is invalid' do
    before do
      @manifest_hash = { 'location' => { 'freshdesk' => { 'ticket_sidebar' => 'app.html' } } }
    end

    it 'should have an error' do
      expect(@package).to have_error(/invalid host/)
    end
  end

  context 'location is invalid' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'sidebar.html', 'a_invalid_location' => 'https://i.am.so.conf/used/setup.exe' } } }
    end

    it 'should have an error' do
      expect(@package).to have_error(/invalid location in/)
    end
  end

  context 'location is localhost' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'http://localhost:9999/' } } }
    end

    it 'should not have an error' do
      expect(@package).not_to have_error(/invalid location/)
    end
  end

  context 'location uri is not HTTPS' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'http://mysite.com/zendesk_iframe' } } }
    end

    it 'should have an error' do
      expect(@package).to have_error(/invalid location URI/)
    end
  end

  context 'location uri is invalid' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => '\\' } } }
    end

    it 'should have an error when the location is an invalid URI' do
      expect(@package).to have_error(/invalid location URI/)
    end
  end

  context 'location references a correct URI' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'https://mysite.com/zendesk_iframe' } } }
    end

    it 'should not have a location error' do
      expect(@package).not_to have_error(/invalid location/)
    end
  end

  context 'location references a correct URI' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => { 'url' => 'https://mysite.com/zendesk_iframe' } } } }
    end

    it 'should not have a location error' do
      expect(@package).not_to have_error(/invalid location/)
    end
  end

  context 'location uri is blank' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => '' } } }
    end

    it 'should not have a location error' do
      expect(@package).to have_error(/location does not specify a URI/)
    end
  end

  context 'location is manual load and has no uri' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => { 'autoLoad' => false } } } }
    end

    it 'should not have a location error' do
      expect(@package).not_to have_error(/invalid location/)
      expect(@package).not_to have_error(/cannot specify both a URI and the noIframe option/)
      expect(@package).not_to have_error(/location does not specify a URI/)
    end
  end

  context 'location is manual load and specifies references a url' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => { 'autoLoad' => false, 'url' => 'https://i.am.so.conf/used/setup.exe' } } } }
    end

    it 'should not have a location error' do
      expect(@package).not_to have_error(/invalid location/)
      expect(@package).not_to have_error(/cannot specify both a URI and the noIframe option/)
      expect(@package).not_to have_error(/location does not specify a URI/)
    end
  end

  context 'location references a file outside of assets folder' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'manifest.json' } } }
    end

    before do
      allow(@package).to receive(:has_file?).with('manifest.json').and_return(true)
    end

    it 'should have an error' do
      expect(@package).to have_error(/invalid location URI/)
    end
  end

  context 'location references a missing file' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'assets/herp.derp' } } }
    end

    it 'should have an error' do
      expect(@package).to have_error(/invalid location URI/)
    end
  end

  context 'location references a valid asset file' do
    before do
      @manifest_hash = { 'location' => { 'zendesk' => { 'ticket_sidebar' => 'assets/iframe.html' } } }
    end

    before do
      allow(@package).to receive(:has_file?).with('assets/iframe.html').and_return(true)
    end

    it 'should not have an error' do
      expect(@package).not_to have_error(/invalid location URI/)
    end
  end

  context 'a v1 app with v2 locations' do
    before do
      @manifest_hash = {
        'location' => { 'zendesk' => { 'ticket_sidebar' => 'assets/iframe.html' } },
        'frameworkVersion' => '1.0'
      }
      allow(@package).to receive(:has_file?).with('assets/iframe.html').and_return(true)
    end

    it 'should have an error' do
      expect(@package).to have_error(/must not be URLs/)
    end
  end

  context 'a v2 app with v1 locations' do
    before do
      @manifest_hash = {
        'location' => 'ticket_sidebar',
        'frameworkVersion' => '2.0'
      }
      allow(@package).to receive(:has_file?).with('assets/iframe.html').and_return(true)
    end

    it 'should have an error' do
      expect(@package).to have_error(/need to be URLs/)
    end
  end

  it 'should have an error when there are duplicate locations' do
    @manifest_hash = { 'location' => %w(ticket_sidebar ticket_sidebar) }

    expect { @package.validate }.to raise_error(/Duplicate reference in manifest: "ticket_sidebar"/)
  end

  it 'should have an error when the version is not supported' do
    @manifest_hash = { 'frameworkVersion' => '0.7' }

    expect(@package).to have_error(/not a valid framework version/)
  end

  it 'should have an error when a hidden parameter is set to required' do
    @manifest_hash = {
      'parameters' => [
        'name'     => 'a parameter',
        'type'     => 'hidden',
        'required' => true
      ]
    }

    expect(@package).to have_error(/set to hidden and cannot be required/)
  end

  it 'should have an error when manifest is not a valid json' do
    allow(@package).to receive(:manifest) { raise JSON::ParserError.new }

    expect(@package).to have_error(/^manifest is not proper JSON/)
  end

  it 'should have an error when required oauth fields are missing' do
    oauth_hash = {
      'oauth' => {}
    }
    expect(create_package(oauth_hash)).to have_error \
      'Missing required oauth fields in manifest: client_id, client_secret, authorize_uri, access_token_uri'
  end

  it 'should have an error when a non-boolean is passed for a field that must be boolean' do
    expect(create_package('singleInstall' => 'false')).to have_error(/must be a boolean value/)
  end

  it 'should have an error when noTemplate is not a boolean or an array' do
    expect(create_package('noTemplate' => 12)).to have_error(:invalid_no_template)
  end

  it 'should have an error when noTemplate is a garbage array' do
    expect(create_package('noTemplate' => ['ticket_sidebar', 'someplace else'])).to have_error(:invalid_no_template)
  end

  context 'with invalid parameters' do
    before do
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:default_locale_error)
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:invalid_location_error)
      allow(ZendeskAppsSupport::Validations::Manifest).to receive(:invalid_version_error)
    end

    it 'has an error when the app parameters are not an array' do
      parameter_hash = {
        'parameters' => {
          'name' => 'a parameter',
          'type' => 'text'
        }
      }

      expect(create_package(parameter_hash)).to have_error 'App parameters must be an array.'
    end

    it 'has an error when there is a parameter called "name"' do
      parameter_hash = {
        'parameters' => [{
          'name' => 'name',
          'type' => 'text'
        }]
      }

      expect(create_package(parameter_hash)).to have_error "Can't call a parameter 'name'"
    end

    it "doesn't have an error with an array of app parameters" do
      parameter_hash = {
        'parameters' => [{
          'name' => 'a parameter',
          'type' => 'text'
        }]
      }

      expect(create_package(parameter_hash)).not_to have_error
    end

    it 'behaves when the manifest does not have parameters' do
      expect(create_package(default_required_params)).not_to have_error
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

      expect(create_package(parameter_hash)).to have_error 'Duplicate app parameters defined: ["url"]'
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
      expect(create_package(parameter_hash)).to have_error 'integer is an invalid parameter type.'
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
      expect(create_package(parameter_hash)).not_to have_error
    end

    it "doesn't have an error with a missing parameter type" do
      parameter_hash = {
        'parameters' =>
        [
          {
            'name' => 'valid parameter'
          }
        ]
      }
      package = create_package(parameter_hash)
      expect(package.manifest.parameters.first.type).to eq 'text'
      expect(package).not_to have_error
    end
  end
end
