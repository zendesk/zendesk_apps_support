require 'multi_json'

module ZendeskAppsSupport
  module Validations
    module Manifest

      REQUIRED_MANIFEST_FIELDS = %w( author defaultLocale ).freeze

      class <<self
        def call(package)
          manifest = package.files.find { |f| f.relative_path == 'manifest.json' }

          return [ ValidationError.new('txt.apps.admin.error.app_build.missing_manifest') ] unless manifest

          manifest = MultiJson.load(manifest.read)
          missing = missing_keys(manifest)
          return [ ValidationError.new('txt.apps.admin.error.app_build.missing_manifest_keys', :missing_keys => missing.join(', '), :count => missing.length) ] if missing.any?

          []
        rescue MultiJson::DecodeError => e
          return [ ValidationError.new('txt.apps.admin.error.app_build.missing_manifest_keys', :errors => e) ]
        end

        private

        def missing_keys(manifest)
          REQUIRED_MANIFEST_FIELDS.select do |key|
            manifest[key].nil?
          end
        end

      end
    end
  end
end
