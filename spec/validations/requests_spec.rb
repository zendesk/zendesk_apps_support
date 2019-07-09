# frozen_string_literal: true

require 'spec_helper'

def request_function(style, address)
  case style
  when 'ZAF'
    "function request() { client.request('#{address}') }"
  when 'jQuery'
    "function request() { jQuery.get('#{address}') }"
  when 'jQuery$'
    "function request() { $.ajax('#{address}') }"
  when 'XMLHttpRequest'
    "function request() { xhr.open('get', '#{address}') }"
  when 'fetch'
    "function request() { fetch('#{address}') }"
  end
end

request_function_styles = %w[ZAF jQuery jQuery$ XMLHttpRequest fetch]

shared_examples 'an insecure request' do |file_path, function_style|
  address = 'http://foo.com'
  let(:markup) { request_function(function_style, address) }

  it "and raise a warning inside #{function_style} style requests" do
    errors = subject.call(package)
    expect(package.warnings[0]).to include('insecure HTTP request', address, file_path)
    expect(errors).to be_empty
  end
end

blocked_ips = {
  private: {
    range: '10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16',
    example: '192.168.0.1'
  },
  loopback: {
    range: '127.0.0.0/8',
    example: '127.0.0.1'
  },
  link_local: {
    range: '169.254.0.0/16',
    example: '169.254.0.1'
  }
}

shared_examples 'a blocked ip' do |file_path, function_style, ip_type, ip|
  let(:markup) { request_function(function_style, "https://#{ip}") }

  it "and throw a #{ip_type} ip error inside #{function_style} style request calls" do
    errors = subject.call(package)
    expect(package.warnings).to be_empty
    expect(errors[0]).to include("request to a #{ip_type} ip", ip, file_path)
  end
end

describe ZendeskAppsSupport::Validations::Requests do
  app_js_path = 'assets/app.js'
  let(:app_js) { double('AppFile', relative_path: app_js_path, read: markup) }
  let(:subject) { ZendeskAppsSupport::Validations::Requests }
  let(:package) { double('Package', js_files: [app_js], html_files: [], warnings: []) }

  describe 'using the http protocol' do
    request_function_styles.each { |function_style| it_behaves_like 'an insecure request', app_js_path, function_style }
  end

  blocked_ips.each do |type, ip|
    describe "to #{ip[:range]} range ips" do
      request_function_styles.each do |function_style|
        type_localised = ZendeskAppsSupport::I18n.t("txt.apps.admin.error.app_build.blocked_request_#{type}")
        it_behaves_like 'a blocked ip', app_js_path, function_style, type_localised, ip[:example]
      end
    end
  end
end
