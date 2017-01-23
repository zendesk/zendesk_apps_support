require 'erubis'

module ZendeskAppsSupport
  class Installed
    INSTALLED_TEMPLATE = Erubis::Eruby.new(File.read(File.expand_path('../assets/installed.js.erb', __FILE__)))

    def initialize(appsjs, installations = [])
      @appsjs = appsjs
      @installations = installations
    end

    def compile_js(options = {})
      INSTALLED_TEMPLATE.result(
        appsjs: @appsjs,
        installations: @installations,
        installation_orders: options.fetch(:installation_orders, {})
        rollbar_zaf_access_token: options.fetch(:rollbar_zaf_access_token, "")
      )
    end
  end
end
