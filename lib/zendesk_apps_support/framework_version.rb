module ZendeskAppsSupport

  # At any point in time, we support up to three versions:
  #  * deprecated -- we will still serve apps targeting the deprecated version,
  #                  but newly created or updated apps CANNOT target it
  #  * current    -- we will serve apps targeting the current version;
  #                  newly created or updated apps SHOULD target it
  #  * future     -- we will serve apps targeting the future version;
  #                  newly created or updates apps MAY target it, but it
  #                  may change without notice
  class FrameworkVersion

    DEPRECATED = '0.4'.freeze
    CURRENT    = '0.5'.freeze
    FUTURE     = '1.0'.freeze

    def initialize(deprecate = false)
      @deprecate = deprecate
    end

    def deprecate?
      @deprecate
    end

    def deprecated
      return CURRENT if deprecate?
      DEPRECATED
    end

    def current
      return FUTURE if deprecate?
      CURRENT
    end

    def future
      return nil if deprecate?
      FUTURE
    end

    def servable
      [ deprecated, current, future ].compact
    end

    def valid_for_update
      [ current, future ].compact
    end

    def obsolete?
      !servable?
    end

    def present?
      !blank?
    end
  end

end
