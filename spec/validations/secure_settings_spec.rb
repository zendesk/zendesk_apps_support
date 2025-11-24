# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::SecureSettings do
  let(:package) { double('Package', warnings: []) }
  let(:secured_param_no_scopes) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token', 'secure' => true) }
  let(:secured_param_oauth_no_scopes) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'oauth_token', 'secure' => true) }
  let(:secured_param_with_scopes) do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'token_with_scopes', 'secure' => true, 'scopes' => ['header'])
  end
  let(:insecure_param) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_insecure_token') }
  let(:regular_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain') }
  let(:regular_default_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain', 'default' => true) }
  let(:secured_default_param)  do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'secured_default_subdomain',
                                                'secure' => true,
                                                'default' => true)
  end
  let(:hidden_default_param) do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain',
                                                'type' => 'hidden',
                                                'default' => true)
  end

  context 'when default manifest parameters are not secure or hidden' do
    it 'returns no warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [regular_param, regular_default_param] }
      subject.call(package)

      expect(package.warnings).to be_empty
    end
  end

  context 'when default manifest parameters are secure' do
    it 'returns a warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [secured_default_param] }
      subject.call(package)

      expect(package.warnings.size).to eq(2)
      expect(package.warnings[0]).to include('confirm they do not contain sensitive data')
      expect(package.warnings[1]).to include('Make sure to set scopes for secure Settings: secured_default_subdomain')
    end
  end

  context 'when default manifest parameters are hidden' do
    it 'returns a warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [hidden_default_param] }
      subject.call(package)

      expect(package.warnings.size).to eq(1)
      expect(package.warnings[0]).to include('confirm they do not contain sensitive data')
    end
  end

  context 'when manifest parameters do not contain SECURABLE_KEYWORDS' do
    it 'returns no warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [regular_param] }
      subject.call(package)

      expect(package.warnings).to be_empty
    end
  end

  context 'when manifest parameters contain SECURABLE_KEYWORDS' do
    it 'returns a warning if secure key is false/undefined' do
      allow(package).to receive_message_chain('manifest.parameters') { [ insecure_param, regular_param ] }
      subject.call(package)

      expect(package.warnings.size).to eq(2)
      expect(package.warnings[0]).to include('Make sure to set secure to true')
      expect(package.warnings[1]).to eq('Make sure to set scopes for secure Settings: my_insecure_token')
    end

    it 'returns warning only for parameters that are secure but with no scopes' do
      allow(package).to receive_message_chain('manifest.parameters') do
        [secured_param_no_scopes, secured_param_oauth_no_scopes, secured_param_with_scopes, regular_param]
      end
      subject.call(package)

      expect(package.warnings.size).to eq(1) 
      expect(package.warnings[0]).to eq('Make sure to set scopes for secure Settings: my_token, oauth_token')
    end

    it 'show warning for secured, insecured, default parameters' do
      allow(package).to receive_message_chain('manifest.parameters') do
        [
          secured_param_no_scopes,
          secured_param_oauth_no_scopes,
          secured_param_with_scopes,
          insecure_param,
          regular_param,
          regular_default_param,
          secured_default_param
        ]
      end
      subject.call(package)

      expect(package.warnings.size).to eq(3)
      expect(package.warnings[0]).to include('Make sure to set secure to true when using keys in Settings')
      expect(package.warnings[1]).to include('Default values for secure or hidden parameters are not stored securely')
      expect(package.warnings[2]).to eq(
        'Make sure to set scopes for secure Settings: my_token, oauth_token, my_insecure_token, secured_default_subdomain'
      )
    end

    it 'returns no warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [ secured_param_with_scopes, regular_param ] }
      subject.call(package)

      expect(package.warnings).to be_empty
    end
  end
end
