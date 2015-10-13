require 'erubis'

module ZendeskAppsSupport
  class Installation

    attr_reader :package

    INSTALLATION_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installation.js.erb', __FILE__)) )

    def initialize(package)
      @package = package
    end

    def readified_js(meta, settings)
      INSTALLATION_TEMPLATE.result(
        id: meta[:installation_id],
        app_id: meta[:app_id],
        app_name: @package.name,
        settings: settings,
        requirements: @package.has_requirements? ? @package.requirements : {},
        enabled: meta[:enabled],
        updated: meta[:updated],
        updated_at: meta[:updated_at],
        created_at: meta[:created_at]
      )
    end
  end
end
