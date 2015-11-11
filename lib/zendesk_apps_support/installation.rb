require 'erubis'

module ZendeskAppsSupport
  class Installation

    INSTALLATION_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installation.js.erb', __FILE__)) )

    def self.readified_js(serialized_installation)
      INSTALLATION_TEMPLATE.result(serialized_installation: serialized_installation)
    end
  end
end
