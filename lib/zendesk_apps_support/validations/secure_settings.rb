# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module SecureSettings
      SECURABLE_KEYWORDS = %w[token key pwd password].freeze
      SECURABLE_KEYWORDS_REGEXP = Regexp.new(SECURABLE_KEYWORDS.join('|'), Regexp::IGNORECASE)

      class << self
        def call(package)
          manifest_params = package.manifest.parameters

          insecure_params_found = manifest_params.any? { |param| insecure_param?(param) }

          package.warnings << secure_settings_warning if insecure_params_found
        end

        private

        def insecure_param?(parameter)
          parameter.name =~ SECURABLE_KEYWORDS_REGEXP && type_password_or_text?(parameter.type) && !parameter.secure
        end

        def type_password_or_text?(parameter_type)
          parameter_type == 'text' || parameter_type == 'password'
        end

        def secure_settings_warning
          I18n.t(
            'txt.apps.admin.error.app_build.translation.insecure_token_parameter_in_manifest',
            link: 'https://developer.zendesk.com/apps/docs/developer-guide/using_sdk#using-secure-settings'
          )
        end
      end
    end
  end
end
