module ZendeskAppsSupport
  module Validations
    module Marketplace
      class << self
        def call(package)
          [no_symlinks(package.root)].compact
        end

        private

        def no_symlinks(path)
          if Dir["#{path}/**/{*,.*}"].any? { |f| File.symlink?(f) }
            return ValidationError.new(:symlink_in_zip)
          end
          nil
        end
      end
    end
  end
end
