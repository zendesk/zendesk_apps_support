# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Installed do
  before do
    appjs = File.read('spec/fixtures/legacy_app_en.js')
    @installed = ZendeskAppsSupport::Installed.new([appjs])
  end

  describe 'compile' do
    it 'should render installed.js' do
      installedjs = @installed.compile(installation_orders: {},
                                       rollbar_zaf_access_token: 'test token')

      expected_installedjs = File.read('spec/fixtures/installed.js')
      expect(installedjs.gsub(/\s+/, ' ')).to eq(expected_installedjs.gsub(/\s+/, ' '))
    end
  end
end
