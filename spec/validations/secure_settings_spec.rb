# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::SecureSettings do
  let(:package) { double('Package', warnings: []) }
  let(:secured_param_no_scopes) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token', 'secure' => true) }
  let(:secured_param_oauth_no_scopes) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'oauth_token', 'secure' => true) }
  let(:secured_param_with_scopes) do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'token_with_scopes', 'secure' => true, 'scopes' => ['header'])
  end
  let(:secured_param_with_nil_scopes) do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'token_with_nil_scopes', 'secure' => true, 'scopes' => nil)
  end
  let(:secured_param_with_empty_scopes) do
    ZendeskAppsSupport::Manifest::Parameter.new('name' => 'token_with_empty_scopes', 'secure' => true, 'scopes' => [])
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
      expect(package.warnings[1]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): secured_default_subdomain. This may cause token exposure vulnerabilities. Learn more:'
      )
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

      expect(package.warnings.size).to eq(1)
      expect(package.warnings[0]).to include('Make sure to set secure to true')
    end

    it 'returns warning only for parameters that are secure but with no scopes' do
      allow(package).to receive_message_chain('manifest.parameters') do
        [secured_param_no_scopes, secured_param_oauth_no_scopes, secured_param_with_scopes, regular_param]
      end
      subject.call(package)

      expect(package.warnings.size).to eq(1) 
      expect(package.warnings[0]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): my_token, oauth_token. This may cause token exposure vulnerabilities. Learn more:'
      )
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
      expect(package.warnings[2]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): my_token, oauth_token, secured_default_subdomain. This may cause token exposure vulnerabilities. Learn more:'
      )
    end

    it 'returns no warning' do
      allow(package).to receive_message_chain('manifest.parameters') { [secured_param_with_scopes, regular_param] }
      subject.call(package)

      expect(package.warnings).to be_empty
    end
  end

  context 'when scopes are falsy,' do
    it 'return warning for nil scopes' do
      allow(package).to receive_message_chain('manifest.parameters') { [secured_param_with_nil_scopes] }
      subject.call(package)

      expect(package.warnings[0]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): token_with_nil_scopes. This may cause token exposure vulnerabilities. Learn more:'
      )
    end

    it 'return warning for [] scopes' do
      allow(package).to receive_message_chain('manifest.parameters') { [secured_param_with_empty_scopes] }
      subject.call(package)

      expect(package.warnings[0]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): token_with_empty_scopes. This may cause token exposure vulnerabilities. Learn more:'
      )
    end

    it 'return warning for nil and [] scopes' do
      allow(package).to receive_message_chain('manifest.parameters') do
        [secured_param_with_nil_scopes, secured_param_with_empty_scopes]
      end
      subject.call(package)

      expect(package.warnings[0]).to include(
        'SECURITY: Secure settings scopes are not configured for parameter(s): token_with_nil_scopes, token_with_empty_scopes. This may cause token exposure vulnerabilities. Learn more:'
      )
    end
  end
end
