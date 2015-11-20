module ZendeskAppsSupport
  class Installation

    attr_accessor :id, :app_id, :app_name, :requirements, :settings, :enabled, :updated_at, :created_at

    def initialize(options)
      options.each do |k, v|
        public_send("#{k}=", v)
      end
    end
  end
end
