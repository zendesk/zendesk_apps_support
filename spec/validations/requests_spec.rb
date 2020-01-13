# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::Requests do
  let(:package) { double('Package', warnings: [], html_files: []) }
  let(:app_file) { double('AppFile', relative_path: 'app_file.js') }

  before do
    allow(package).to receive(:js_files) { [app_file] }
    allow(package).to receive_message_chain(:manifest, :private?).and_return(false)
  end

  context 'http protocols check' do
    it 'returns no warnings for files that contain https urls' do
      allow(app_file).to receive(:read) { "client.instance(\"https://foo-bar.com\");\r\n\t" }

      subject.call(package)
      expect(package.warnings).to be_empty
    end

    it 'returns warning with request information when files contain http url' do
      allow(app_file).to receive(:read) { "client.instance(\"http://foo-bar.com\");\r\n\t" }

      subject.call(package)
      expect(package.warnings[0]).to include(
        'Possible insecure HTTP request',
        'foo-bar.com',
        'in app_file.js',
        'Consider using the HTTPS protocol instead.'
      )
    end
  end
end
