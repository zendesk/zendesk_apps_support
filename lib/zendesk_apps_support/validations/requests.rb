# frozen_string_literal: true

require 'ipaddress_2'
require 'uri'

module ZendeskAppsSupport
  module Validations
    module Requests
      class << self
        IP_ADDRESS = /\b(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\b/

        def call(package)
          errors = []
          files = package.js_files + package.html_files

          files.each do |file|
            file_content = file.read

            http_protocol_urls = find_address_containing_http(file_content)
            if http_protocol_urls.any?
              package.warnings << I18n.t(
                'txt.apps.admin.warning.app_build.insecure_http_request',
                uri: http_protocol_urls.join(I18n.t('txt.apps.admin.error.app_build.listing_comma')),
                file: file.relative_path
              )
            end

            ip_addresses = file_content.scan(IP_ADDRESS)
            if ip_addresses.any?
              errors << blocked_ips_validation(file.relative_path, ip_addresses)
            end
          end

          errors
        end

        private

        def blocked_ips_validation(file_path, ip_addresses)
          ip_addresses.each_with_object([]) do |ip_address, error_messages|
            blocked_type = blocked_ip_type(ip_address)
            next unless blocked_type

            error_messages << ValidationError.new(
              :blocked_request,
              type: blocked_type,
              uri:  ip_address,
              file: file_path
            )
          end
        end

        def blocked_ip_type(ip_address)
          block_type =
            case IPAddress.parse(ip_address)
            when proc(&:private?) then 'private'
            when proc(&:loopback?) then 'loopback'
            when proc(&:link_local?) then 'link_local'
            end

          block_type && I18n.t("txt.apps.admin.error.app_build.blocked_request_#{block_type}")
        end

        def find_address_containing_http(file_content)
          file_content.scan(URI.regexp(['http'])).map(&:compact).map(&:last)
        end
      end
    end
  end
end
