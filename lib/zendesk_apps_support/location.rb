module ZendeskAppsSupport
  module Location
    # the numbers below match the enum values on the database, do not change them!
    LOCATIONS_AVAILABLE = {
      "zendesk" => {
        "top_bar" => 1,
        "nav_bar" => 2,
        "ticket_sidebar" => 3,
        "new_ticket_sidebar" => 4,
        "user_sidebar" => 5,
        "organization_sidebar" => 6,
        "background" => 7
      },
      "zopim" => {
        "chat_sidebar" => 8
      }
    }.freeze

    class << self
      def hosts
        LOCATIONS_AVAILABLE.keys
      end

      def names_for(host)
        LOCATIONS_AVAILABLE[host.to_s].keys
      end
    end
  end
end
