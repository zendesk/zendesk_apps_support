# frozen_string_literal: true

module ZendeskAppsSupport
  # At any point in time, we support up to four versions:
  #  * deprecated -- we will still serve apps targeting the deprecated version,
  #                  but newly created or updated apps CANNOT target it
  #  * sunsetting -- we will soon be removing support for this version;
  #                  updated apps SHOULD target the current version, no new apps allowed
  #  * current    -- we will serve apps targeting the current version;
  #                  newly created or updated apps SHOULD target it
  #  * future     -- we will serve apps targeting the future version;
  #                  newly created or updates apps MAY target it, but it
  #                  may change without notice
  class AppVersion
    DEPRECATED = [].freeze
    SUNSETTING = nil
    CURRENT    = '2.0'
    FUTURE     = nil

    TO_BE_SERVED     = [DEPRECATED, SUNSETTING, CURRENT, FUTURE].flatten.compact.freeze
    VALID_FOR_UPDATE = [SUNSETTING, CURRENT, FUTURE].compact.freeze
    VALID_FOR_CREATE = [CURRENT, FUTURE].compact.freeze

    attr_reader :current

    def initialize(version)
      @version = version.to_s.freeze
      @current = CURRENT
      freeze
    end

    def servable?
      TO_BE_SERVED.include?(@version)
    end

    def valid_for_update?
      VALID_FOR_UPDATE.include?(@version)
    end

    def valid_for_create?
      VALID_FOR_CREATE.include?(@version)
    end

    def deprecated?
      DEPRECATED.include?(@version)
    end

    def sunsetting?
      @version == SUNSETTING
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
end
