module ZendeskAppsSupport
  module Location
    # the numbers below match the enum values on the database, do not change them!
    LOCATIONS_AVAILABLE = {
      'zendesk' => {
        'top_bar' => { 'id' => 1, 'orderable' => true },
        'nav_bar' => { 'id' => 2, 'orderable' => true },
        'ticket_sidebar' => { 'id' => 3, 'orderable' => true },
        'new_ticket_sidebar' => { 'id' => 4, 'orderable' => true },
        'user_sidebar' => { 'id' => 5, 'orderable' => true },
        'organization_sidebar' => { 'id' => 6, 'orderable' => true },
        'background' => { 'id' => 7, 'orderable' => false }
      },
      'zopim' => {
        'chat_sidebar' => { 'id' => 8, 'orderable' => false }
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
