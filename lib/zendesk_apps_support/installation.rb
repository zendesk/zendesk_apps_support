module ZendeskAppsSupport
  class Installation

    attr_accessor :id, :app_id, :app_name, :requirements, :settings, :enabled, :updated_at, :created_at

    def initialize(options)
      options.each do |k, v|
        public_send("#{k}=", v)
      end
    end

    def to_json
      hash = {}
      self.instance_variables.each do |var|
        hash[var.to_s.sub('@', '')] = self.instance_variable_get var
      end
      hash.to_json
    end
  end
end
