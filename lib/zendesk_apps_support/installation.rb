# frozen_string_literal: true

module ZendeskAppsSupport
  class Installation
    attr_accessor :id, :app_id, :app_name, :requirements, :settings, :enabled, :collapsible, :updated_at, :created_at
    attr_accessor :plan

    def initialize(options)
      options.each do |k, v|
        public_send("#{k}=", v)
      end
    end

    def to_json
      hash = {}
      instance_variables.each do |var|
        hash[var.to_s.sub('@', '')] = instance_variable_get var
      end
      hash.to_json
    end
  end
end
