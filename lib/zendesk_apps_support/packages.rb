require 'erubis'

module ZendeskAppsSupport
  class Packages
    INSTALLED_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installed.js.erb', __FILE__)) )

    def initialize(packages)
      @packages = packages
    end

    def readified_js(installations, installation_order, asset_url_prefix, locale = 'en')
      INSTALLED_TEMPLATE.result(
        apps: @packages.map {|package| package.readified_js(asset_url_prefix, locale) },
        installations: installations,
        installation_orders: installation_order
      )
    end
  end
end
