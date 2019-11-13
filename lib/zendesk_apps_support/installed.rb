# frozen_string_literal: true

require 'erubis'

module ZendeskAppsSupport
  class Installed
    extend Gem::Deprecate
    INSTALLED_TEMPLATE = Erubis::Eruby.new(File.read(File.expand_path('../assets/installed.js.erb', __FILE__)))

    def initialize(appsjs, installations = [])
      @appsjs = appsjs
      @installations = installations
    end

    def obj(options = {})
      {
        apps: @appsjs,
        installation_orders: options.fetch(:installation_orders, {}),
        installations: @installations,
        rollbar_zaf_access_token: options.fetch(:rollbar_zaf_access_token, '')
      }
    end

    def compile(options = {})
      INSTALLED_TEMPLATE.result(
        appsjs: @appsjs,
        installations: @installations,
        installation_orders: options.fetch(:installation_orders, {}),
        rollbar_zaf_access_token: options.fetch(:rollbar_zaf_access_token, '')
      )
    end

    alias compile_js compile
    deprecate :compile_js, :compile, 2017, 1
  end
end
