require 'multi_json'

module ZendeskAppsSupport

  class AppVersion

    def initialize(version, deprecate = false)
      @framework_version = FrameworkVersion.new(deprecate)
      @version = version.to_s
      @version.freeze
    end

    def servable?
      @framework_version.servable.include?(@version)
    end

    def updatable?
      @framework_version.updatable.include?(@version)
    end

    def deprecated?
      @version == @framework_version.deprecated
    end

    def blank?
      @version.nil? || @version == ''
    end

    def obsolete?
      !servable?
    end

    def to_s
      @version
    end

    def to_json(*options)
      MultiJson.encode(@version)
    end

    def ==(other)
      @version == other.to_s
    end

  end

end
