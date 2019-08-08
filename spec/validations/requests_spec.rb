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
    let(:validation_error_class) { ZendeskAppsSupport::Validations::ValidationError }
    define_method(:script_containing_ip) { |ip_address_type| "client.request(\"#{ip_address_type}\");\r\n\t" }

    after { subject.call(package) }

    it 'returns no validation error when scanning regular IP' do
      allow(app_file).to receive(:read) { script_containing_ip('64.233.191.255') }
      expect(validation_error_class).to_not receive(:new)
    end

    it 'ignores numbers that are invalid IP Adresses' do
      allow(app_file).to receive(:read) { script_containing_ip('857.384.857.857') }
      expect(validation_error_class).to_not receive(:new)
    end

    it 'returns a validation error when scanning private IP' do
      private_ip = '192.168.0.1'
      allow(app_file).to receive(:read) { script_containing_ip(private_ip) }
      expect(validation_error_class)
        .to receive(:new)
        .with(:blocked_request, type: 'private', uri: private_ip, file: app_file.relative_path)
    end

    it 'returns a validation error when scanning loopback IP' do
      loopback_ip = '127.0.0.1'
      allow(app_file).to receive(:read) { script_containing_ip(loopback_ip) }
      expect(validation_error_class)
        .to receive(:new)
        .with(:blocked_request, type: 'loopback', uri: loopback_ip, file: app_file.relative_path)
    end

    it 'returns a validation error when scanning link_local IP' do
      link_local_ip = '169.254.0.1'
      allow(app_file).to receive(:read) { script_containing_ip(link_local_ip) }
      expect(validation_error_class)
        .to receive(:new)
        .with(:blocked_request, type: 'link-local', uri: link_local_ip, file: app_file.relative_path)
    end
  end
end
