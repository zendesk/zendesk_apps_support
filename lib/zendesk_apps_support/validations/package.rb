module ZendeskAppsSupport
  module Validations
    module Package

      class <<self
        def call(package)
          [].tap do |errors|
            errors << has_location_or_requirements(package)
            errors.compact!
          end
        end

        private

        def has_location_or_requirements(package)
          if !package.has_location? && !package.has_requirements?
            ValidationError.new('package.missing_location_and_requirements')
          end
        end

      end
    end
  end
end
