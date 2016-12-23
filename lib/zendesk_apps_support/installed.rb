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

    def compile(options = {})
      installation_order = options.fetch(:installation_orders, {})

      INSTALLED_TEMPLATE.result(
        appsjs: @appsjs,
        installations: @installations,
        installation_orders: installation_order
      )
    end

    alias compile_js compile
    deprecate :compile_js, :compile, 2017, 1
  end
end
