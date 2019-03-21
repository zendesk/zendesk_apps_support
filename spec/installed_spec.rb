# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Installed do
  let(:installations) { [] }

  before do
    appjs = File.read('spec/fixtures/legacy_app_en.js')
    @installed = ZendeskAppsSupport::Installed.new([appjs], installations)
  end

  describe 'compile' do
    let(:installations) do
      [
        ZendeskAppsSupport::Installation.new(id: 10, app_id: 0, app_name: 'ABC'),
        ZendeskAppsSupport::Installation.new(id: 20, app_id: 0, app_name: 'EFC')
      ]
    end

    it 'should render installed.js' do
      installedjs = @installed.compile(installation_orders: {},
                                       rollbar_zaf_access_token: 'test token')

      expected_installedjs = File.read('spec/fixtures/installed.js')
      expect(installedjs.gsub(/\s+/, ' ')).to eq(expected_installedjs.gsub(/\s+/, ' '))
    end
  end
end
