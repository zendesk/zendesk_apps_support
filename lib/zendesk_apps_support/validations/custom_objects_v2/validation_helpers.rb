# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module CustomObjectsV2
      module ValidationHelpers
        private

        def extract_hash_entries(collection)
          return [] unless collection&.any?

          collection.select { |item| item.is_a?(Hash) }
        end

        def count_conditions(conditions)
          return 0 unless conditions.is_a?(Hash)

          Constants::CONDITION_KEYS.sum { |key| conditions[key]&.size || 0 }
        end
      end
    end
  end
end
