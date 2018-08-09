# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Installed do
  before do
    appjs = File.read('spec/fixtures/legacy_app_en.js')
    @installed = ZendeskAppsSupport::Installed.new([appjs])
  end

  describe 'compile' do
    it 'should render installed.js when apps_zaf_naughty_v1_logging is false' do
      installedjs = @installed.compile(installation_orders: {},
                                       rollbar_zaf_access_token: '',
                                       apps_zaf_naughty_v1_logging: false)

      expected_installedjs = File.read('spec/fixtures/installed_no_logging.js')
      expect(installedjs.gsub(/\s+/, ' ')).to eq(expected_installedjs.gsub(/\s+/, ' '))
    end

    it 'should render installed.js when apps_zaf_naughty_v1_logging is true' do
      installedjs = @installed.compile(installation_orders: {},
                                       rollbar_zaf_access_token: '',
                                       apps_zaf_naughty_v1_logging: true)

      expected_installedjs = File.read('spec/fixtures/installed_with_logging.js')
      expect(installedjs.gsub(/\s+/, ' ')).to eq(expected_installedjs.gsub(/\s+/, ' '))
    end

    it 'should render installed.js when apps_zaf_naughty_v1_logging is true & rollbar token is provided' do
      installedjs = @installed.compile(installation_orders: {},
                                       rollbar_zaf_access_token: 'Sample Rollbar Token',
                                       apps_zaf_naughty_v1_logging: true)

      expected_installedjs = File.read('spec/fixtures/installed_with_logging_rollbar.js')
      expect(installedjs.gsub(/\s+/, ' ')).to eq(expected_installedjs.gsub(/\s+/, ' '))
    end
  end
end
