# frozen_string_literal: true
module ZendeskAppsSupport
  # At any point in time, we support up to four types of versions:
  #  * deprecated -- we will still serve apps targeting the deprecated version,
  #                  but newly created or updated apps CANNOT target it
  #  * sunsetting -- we will soon be removing support for this version;
  #                  newly created or updated apps SHOULD target the current version
  #  * current    -- we will serve apps targeting the current version;
  #                  newly created or updated apps SHOULD target it
  #  * future     -- we will serve apps targeting the future version;
  #                  newly created or updates apps MAY target it, but it
  #                  may change without notice
  # Versions can be listed as strings or in arrays
  class AppVersion
    DEPRECATED = '0.5'
    SUNSETTING = '1.0'
    CURRENT    = '2.0'
    FUTURE     = nil

    TO_BE_SERVED     = [DEPRECATED, SUNSETTING, CURRENT, FUTURE].compact.flatten.freeze
    VALID_FOR_UPDATE = [SUNSETTING, CURRENT, FUTURE].compact.flatten.freeze

    attr_reader :current

    def initialize(version)
      @version = version.to_s
      @version.freeze
      @current = CURRENT
      freeze
    end

    def servable?
      TO_BE_SERVED.include?(@version)
    end

    def valid_for_update?
      VALID_FOR_UPDATE.include?(@version)
    end

    def deprecated?
      DEPRECATED.include?(@version)
    end

    def sunsetting?
      SUNSETTING && SUNSETTING.include?(@version)
    end

    def obsolete?
      !servable?
    end

    def blank?
      @version.nil? || @version == ''
    end

    def present?
      !blank?
    end

    def to_s
      @version
    end

    def to_json(*)
      @version.inspect
    end

    def ==(other)
      @version == other.to_s
    end
  end

  AppVersion.freeze
end
