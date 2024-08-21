# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Location do
  describe 'all locations' do
    it 'have unique names per product' do
      per_product = ZendeskAppsSupport::Location.all.group_by(&:product_code)
      unique_location_names = per_product.map { |_, locations| locations.map(&:name).uniq.size }
      all_location_names = per_product.map { |_, locations| locations.map(&:name).size }

      expect(unique_location_names).to eq(all_location_names)
    end

    it 'have unique ids' do
      expect(ZendeskAppsSupport::Location.all.map(&:id)).to eq((1..ZendeskAppsSupport::Location.all.size).to_a)
    end
  end
end
