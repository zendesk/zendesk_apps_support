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

          secure_or_hidden_default_param_found = manifest_params.any? { |param| secure_or_hidden_default_param?(param) }
          package.warnings << hidden_default_parameter_warning if secure_or_hidden_default_param_found

          secure_params_without_scopes = manifest_params.filter_map do |param|
            next unless param.secure

            param.name if secure_param_without_scopes?(param)
          end
          package.warnings << no_scopes_warning(secure_params_without_scopes) if secure_params_without_scopes.any?
        end

        private

        def secure_or_hidden_default_param?(parameter)
          parameter.default? && (parameter.secure || parameter.type == 'hidden')
        end

        def insecure_param?(parameter)
          parameter.name =~ SECURABLE_KEYWORDS_REGEXP && type_password_or_text?(parameter.type) && !parameter.secure
        end

        def type_password_or_text?(parameter_type)
          parameter_type == 'text' || parameter_type == 'password'
        end

        def hidden_default_parameter_warning
          I18n.t(
            'txt.apps.admin.error.app_build.translation.default_secure_or_hidden_parameter_in_manifest'
          )
        end

        def secure_settings_warning
          I18n.t(
            'txt.apps.admin.error.app_build.translation.insecure_token_parameter_in_manifest',
            link: 'https://developer.zendesk.com/apps/docs/developer-guide/using_sdk#using-secure-settings'
          )
        end

        def secure_param_without_scopes?(parameter)
          !parameter.scopes&.any?
        end

        def no_scopes_warning(param_names)
          I18n.t(
            'txt.apps.admin.error.app_build.translation.secure_parameters_with_no_scopes_in_manifest',
            params: param_names.join(', '),
            link: 'https://developer.zendesk.com/documentation/apps/getting-started/setting-up-new-apps/#scopes'
          )
        end
      end
    end
  end
end
