# frozen_string_literal: true

require 'zendesk_apps_support'
require 'i18n'

I18n.enforce_available_locales = false
ZendeskAppsSupport::I18n.set_load_path

def fixture_path(file)
  "#{File.dirname(__FILE__)}/validations/fixture/#{file}"
end

def read_fixture_file(file)
  File.read(fixture_path(file))
end
