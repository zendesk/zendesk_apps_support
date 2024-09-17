# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::I18n do
  it 'should translate error messages' do
    key_prefix = ZendeskAppsSupport::Validations::ValidationError::KEY_PREFIX
    expect(ZendeskAppsSupport::I18n.t("#{key_prefix}.missing_manifest")).to eq('Could not find manifest.json')
  end
end

describe 'translations' do
  it 'should be up-to-date' do
    project_root = Pathname.new(File.expand_path('../../', __FILE__))
    zendesk_version  = project_root.join('config/locales/translations/zendesk_apps_support.yml')
    standard_version = project_root.join('config/locales/en.yml')
    error_message = 'Need to run bundle exec rake i18n:standardize'
    expect(File.mtime(zendesk_version).to_i).to be <= File.mtime(standard_version).to_i, error_message
  end
end
