require 'zendesk_apps_support'
require 'i18n'

I18n.enforce_available_locales = false

def read_fixture_file(file)
  File.read("#{File.dirname(__FILE__)}/validations/fixture/#{file}")
end
