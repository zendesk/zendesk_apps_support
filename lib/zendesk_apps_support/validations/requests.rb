# frozen_string_literal: true

require 'uri'
require 'ipaddress_2'

module ZendeskAppsSupport
  module Validations
    module Requests
      class << self
        HTTP_REQUEST_METHODS = %w[GET HEAD POST PUT DELETE CONNECT OPTIONS TRACE].freeze

        REQUEST_CALLS = [
          /\w+\.request\(['"](.*)['"]/i, # ZAF request
          /(?:\$|jQuery)\.(?:ajax|get|post|getJSON)\(['"](.*)['"]/i, # jQuery request
          /\w+\.open\(['"](?:#{Regexp.union(HTTP_REQUEST_METHODS).source})['"],\s?['"](.*)['"]/i, # XMLHttpRequest
          /fetch\(['"](.*)['"]/i # fetch
        ].freeze

        def call(package)
          errors = []
          files = package.js_files + package.html_files

          files.each do |file|
            contents = file.read
            REQUEST_CALLS.each do |request_pattern|
              request = contents.match(request_pattern)
              next unless request
              uri = URI(request.captures[0])
              if uri.scheme == 'http'
                package.warnings << I18n.t('txt.apps.admin.warning.app_build.insecure_http_request',
                                           uri: uri,
                                           file: file.relative_path)
              end

              next unless IPAddress.valid? uri.host
              ip = IPAddress.parse uri.host

              blocked_ip_type = if ip.private?
                                  I18n.t('txt.apps.admin.error.app_build.blocked_request_private')
                                elsif ip.loopback?
                                  I18n.t('txt.apps.admin.error.app_build.blocked_request_loopback')
                                elsif ip.link_local?
                                  I18n.t('txt.apps.admin.error.app_build.blocked_request_link_local')
                                end

              next unless blocked_ip_type
              errors << I18n.t('txt.apps.admin.error.app_build.blocked_request',
                               type: blocked_ip_type,
                               uri: uri.host,
                               file: file.relative_path)
            end
          end
          errors
        end
      end
    end
  end
end
