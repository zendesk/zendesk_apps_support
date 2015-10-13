require 'erubis'

module ZendeskAppsSupport
  class Installed
    INSTALLED_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installed.js.erb', __FILE__)) )

    def initialize(appsjs, installationsjs)
      @appsjs = appsjs
      @installationsjs = installationsjs
    end

    def readified_js(installation_order)
      INSTALLED_TEMPLATE.result(
        appsjs: @appsjs,
        installationsjs: @installationsjs,
        installation_orders: installation_order
      )
    end
  end
end
