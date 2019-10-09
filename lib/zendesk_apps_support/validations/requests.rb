# frozen_string_literal: true

require 'ipaddress_2'
require 'uri'

module ZendeskAppsSupport
  module Validations
    module Requests
      class << self
        IP_ADDRESS = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/

        def call(package)
          errors = []
          files = package.js_files + package.html_files
          private_app = package.manifest.private?

          files.each do |file|
            file_content = file.read

            http_protocol_urls = find_address_containing_http(file_content)
            if http_protocol_urls.any?
              package.warnings << insecure_http_requests_warning(
                http_protocol_urls,
                file.relative_path
              )
            end

            ip_addresses = file_content.scan(IP_ADDRESS)
            next unless ip_addresses.any?

            ip_validation_messages = ip_validation_messages(
              file.relative_path,
              ip_addresses,
              private_app
            )

            validation_group = private_app ? package.warnings : errors
            validation_group << ip_validation_messages
          end

          package.warnings.flatten!
          errors
        end

        private

        def ip_validation_messages(file_path, ip_addresses, private_app)
          ip_addresses.each_with_object([]) do |ip_address, messages|
            ip_type_string = ip_type_string(ip_address)
            next unless ip_type_string

            string_params = {
              type: ip_type_string, uri: ip_address, file: file_path
            }
            validation_message =
              if private_app
                I18n.t('txt.apps.admin.error.app_build.blocked_request', string_params)
              else
                ValidationError.new(:blocked_request, string_params)
              end

            messages << validation_message
          end
        end

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

        def ip_type_string(ip_address)
          block_type =
            case IPAddress.parse(ip_address)
            when proc(&:private?) then 'private'
            when proc(&:loopback?) then 'loopback'
            when proc(&:link_local?) then 'link_local'
            end

          block_type && I18n.t("txt.apps.admin.error.app_build.blocked_request_#{block_type}")
        rescue ArgumentError
          nil # Ignore numbers which are not an IP address
        end

        def find_address_containing_http(file_content)
          file_content.scan(URI.regexp(['http'])).map(&:compact).map(&:last)
        end
      end
    end
  end
end
