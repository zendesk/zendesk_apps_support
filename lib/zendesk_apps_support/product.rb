# frozen_string_literal: true
module ZendeskAppsSupport
  class Product
    extend ZendeskAppsSupport::Finders
    attr_reader :code, :name, :legacy_name

    def initialize(attrs)
      @code = attrs.fetch(:code)
      @name = attrs.fetch(:name)
      @legacy_name = attrs.fetch(:legacy_name)
    end

    def self.all
      PRODUCTS_AVAILABLE
    end

    # The product codes below match the values in the database, do not change them!
    PRODUCTS_AVAILABLE = [
      Product.new(code: 1, name: 'support', legacy_name: 'zendesk'),
      Product.new(code: 2, name: 'chat', legacy_name: 'zopim')
    ].freeze

    SUPPORT = find_by!(name: 'support')
    CHAT = find_by!(name: 'chat')
  end
end
