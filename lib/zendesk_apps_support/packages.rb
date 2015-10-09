require 'erubis'

module ZendeskAppsSupport
  class Packages
    INSTALLED_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installed.js.erb', __FILE__)) )

    def initialize(packages, settings)
      @packages = packages
      @settings = settings
    end

    def get_installed
      appsjs = []
      @packages.each_with_index do |package, index|
        app_id = -(index+1);
        appsjs << package.readified_js(nil, app_id, "http://localhost:#{@settings.port}/#{app_id}/", package.parameters)
      end

      INSTALLED_TEMPLATE.result(
          :apps => appsjs
      )
    end
  end
end
