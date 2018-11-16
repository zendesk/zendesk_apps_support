# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Libraries
      GARDEN_CDN_URL = /<link\s.*href="(https?:\/\/\S*assets\.zendesk\.com\S*zendesk_garden\.css).*>/
      LEGACY_SDK_URL = /<script\s.*src="(https?:\/\/\S*assets\.zendesk\.com\S*\/((\d(\.\d+){1,2})|latest)\/zaf_sdk\.js).*>/

      class << self
        def call(package)
          errors = []
          package.html_files.each do |file|
            contents = file.read

            if garden_cdn_reference = contents.match(GARDEN_CDN_URL)
              deprecated_url = garden_cdn_reference.captures[0]
              errors << ValidationError.new(:garden_cdn_reference, file: file.relative_path, reference: deprecated_url)
            end

            if legacy_sdk_url_reference = contents.match(LEGACY_SDK_URL)
              deprecated_url = legacy_sdk_url_reference.captures[0]
              version = legacy_sdk_url_reference.captures[1]
              errors << ValidationError.new(:legacy_sdk_url_reference, file: file.relative_path, reference: deprecated_url, current_sdk_url: current_sdk_url(version))
            end
          end
          errors
        end

        private

        def current_sdk_url(version)
          "https://static.zdassets.com/zendesk_app_framework_sdk/#{version}/zaf_sdk.js"
        end
      end
    end
  end
end
