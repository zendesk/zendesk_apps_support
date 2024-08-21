# frozen_string_literal: true

require 'ipaddress_2'
require 'uri'

module ZendeskAppsSupport
  module Validations
    module Requests
      class << self
        def call(package)
          files = package.js_files + package.html_files

          files.each do |file|
            file_content = file.read

            http_protocol_urls = find_address_containing_http(file_content)
            next unless http_protocol_urls.any?
            package.warnings << insecure_http_requests_warning(
              http_protocol_urls,
              file.relative_path
            )
          end

          package.warnings.flatten!
        end

        private

        def insecure_http_requests_warning(http_protocol_urls, relative_path)
          http_protocol_urls = http_protocol_urls.join(
            I18n.t('txt.apps.admin.error.app_build.listing_comma')
          )

          I18n.t(
            'txt.apps.admin.warning.app_build.insecure_http_request',
            uri: http_protocol_urls,
            file: relative_path
          )
        end

        def find_address_containing_http(file_content)
          file_content.scan(URI.regexp(['http'])).map(&:compact).map(&:last)
        end
      end
    end
  end
end
