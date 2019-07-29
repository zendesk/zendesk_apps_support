# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::SecureSettings do
  let(:package) { double('Package', warnings: []) }
  let(:secured_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token', 'secure' => true) }
  let(:insecure_param) { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'my_token') }
  let(:regular_param)  { ZendeskAppsSupport::Manifest::Parameter.new('name' => 'subdomain') }

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
