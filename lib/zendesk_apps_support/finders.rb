module ZendeskAppsSupport
  module Finders
    class RecordNotFound < StandardError
      def initialize(msg)
        super(msg)
      end
    end

    def find_by(arg)
      all.find(&filter_by_arg(arg))
    end

    def find_by!(arg)
      found = find_by(arg)
      fail RecordNotFound.new("Unable to find #{self.name} with #{arg.inspect}") if found.nil?
      found
    end

    def where(arg)
      all.select(&filter_by_arg(arg))
    end

    private

    def filter_by_arg(arg)
      lambda do |product|
        arg.all? do |attribute, value|
          value = value.to_s if value.is_a? Symbol
          product.public_send(attribute) == value
        end
      end
    end
  end
end
