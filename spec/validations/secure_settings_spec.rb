# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::SecureSettings do
  let(:package) { double('Package', warnings: []) }
  let(:secured_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token', 'secure' => true) }
  let(:insecure_param) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token') }
  let(:regular_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain') }
  let(:regular_default_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain', 'default' => true) }
  let(:secured_default_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain', 'secure' => true, 'default' => true) }
  let(:hidden_default_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain', 'type' => 'hidden', 'default' => true) }

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

      expect(package.warnings.size).to eq(1)
      expect(package.warnings[0]).to include('confirm they do not contain sensitive data')
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

    it 'returns no warning if secure key is true' do
      allow(package).to receive_message_chain('manifest.parameters') { [ secured_param, regular_param ] }
      subject.call(package)

      expect(package.warnings).to be_empty
    end
  end
end
