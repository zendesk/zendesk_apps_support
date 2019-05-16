# frozen_string_literal: true

require 'net/http'
require 'json'

module ZendeskAppsSupport
  module Validations
    module Secrets
      SECRET_KEYWORDS = %w[
        pass password secret secretToken secret_token auth_key
        authKey auth_pass authPass auth_user AuthUser username api_key
      ].freeze

      class << self
        def call(package)
          compromised_files = []

          # Rely on the regexes used by truffleHog (https://github.com/dxa4481/truffleHog) to detect application secrets
          trufflehog_regexes = JSON.parse(Net::HTTP.get(URI.parse('https://raw.githubusercontent.com/dxa4481/truffleHogRegexes/master/truffleHogRegexes/regexes.json'))).freeze

          package.text_files.each do |file|
            contents = file.read

            trufflehog_regexes.each do |secret_type, regex_str|
              next unless contents =~ Regexp.new(regex_str)
              package.warnings << I18n.t('txt.apps.admin.warning.app_build.application_secret',
                                         file: file,
                                         secret_type: secret_type)
            end

            compromised_files << file.relative_path if contents =~ Regexp.union(SECRET_KEYWORDS)
          end

          if compromised_files
            package.warnings << I18n.t('txt.apps.admin.warning.app_build.generic_secrets',
                                       files: compromised_files.join(', '),
                                       count: compromised_files.count)
          end
          nil
        end
      end
    end
  end
end
