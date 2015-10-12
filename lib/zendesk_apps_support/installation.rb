module ZendeskAppsSupport
  class Installation

    attr_reader :app

    def initialize(package, installation_id, settings)
      @app = package
      @installation_id = installation_id
      @settings = settings
    end

    def name
      @app.name
    end

    def enabled
      true
    end

    def readified_js()
      app = {
        id: @installation_id,
        app_id: @app.app_id,
        settings: @settings,
        enabled: enabled,
        updated: '',
        updated_at: 'updated_at',
        created_at: 'created_at'
      }

      app[:requirements] = @app.requirements_json if @app.has_requirements?

      app.to_json
    end
  end
end
