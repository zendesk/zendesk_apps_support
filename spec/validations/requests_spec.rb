# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::Requests do
  let(:package) { double('Package', warnings: [], html_files: []) }
  let(:app_file) { double('AppFile', relative_path: 'app_file.js') }

  before { allow(package).to receive(:js_files) { [app_file] } }

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

  context 'IPs check' do
    it 'returns no validation error when scanning regular IP' do
      allow(app_file).to receive(:read) { "client.instance(\"64.233.191.255\");\r\n\t" }
      expect(subject.call(package).flatten).to be_empty
    end

    it 'returns a validation error when scanning private IP' do
      allow(app_file).to receive(:read) { "//var x = '192.168.0.1'\r\n \tclient.get(x)" }
      expect(subject.call(package).flatten[0]).to include('request to a private ip 192.168.0.1')
    end

    it 'returns a validation error when scanning loopback IP' do
      allow(app_file).to receive(:read) { "//var x = '127.0.0.1'\r\n \tclient.get(x)" }
      expect(subject.call(package).flatten[0]).to include('request to a loopback ip 127.0.0.1')
    end

    it 'returns a validation error when scanning link_local IP' do
      allow(app_file).to receive(:read) { "//var x = '169.254.0.1'\r\n \tclient.get(x)" }
      expect(subject.call(package).flatten[0]).to include('request to a link-local ip 169.254.0.1')
    end
  end
end
