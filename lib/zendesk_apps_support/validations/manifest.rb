# rubocop:disable ModuleLength
# frozen_string_literal: true

require 'uri'

module ZendeskAppsSupport
  module Validations
    module Manifest
      RUBY_TO_JSON = ZendeskAppsSupport::Manifest::RUBY_TO_JSON
      REQUIRED_MANIFEST_FIELDS = RUBY_TO_JSON.select { |k| %i[author default_locale].include? k }.freeze
      OAUTH_REQUIRED_FIELDS = %w[client_id client_secret authorize_uri access_token_uri].freeze
      PARAMETER_TYPES = ZendeskAppsSupport::Manifest::Parameter::TYPES
      OAUTH_MANIFEST_LINK = 'https://developer.zendesk.com/apps/docs/developer-guide/manifest#oauth'

      class << self
        def call(package)
          unless package.has_file?('manifest.json')
            nested_manifest = package.files.find { |file| file =~ %r{\A[^/]+?/manifest\.json\Z} }
            if nested_manifest
              return [ValidationError.new(:nested_manifest, found_path: nested_manifest.relative_path)]
            end
            return [ValidationError.new(:missing_manifest)]
          end

          collate_manifest_errors(package)
        rescue JSON::ParserError => e
          return [ValidationError.new(:manifest_not_json, errors: e)]
        rescue ZendeskAppsSupport::Manifest::OverrideError => e
          return [ValidationError.new(:duplicate_manifest_keys, errors: e.message)]
        end

        private

        def collate_manifest_errors(package)
          manifest = package.manifest

          errors = [
            missing_keys_error(manifest),
            type_checks(manifest),
            oauth_error(manifest),
            default_locale_error(manifest, package),
            validate_urls(manifest),
            validate_parameters(manifest),
            if manifest.requirements_only? || manifest.marketing_only?
              [ ban_location(manifest),
                ban_framework_version(manifest) ]
            else
              [ validate_location(package),
                missing_framework_version(manifest),
                invalid_version_error(manifest) ]
            end,
            ban_no_template(manifest)
          ]
          errors.flatten.compact
        end

        def validate_location(package)
          manifest = package.manifest
          [
            missing_location_error(package),
            invalid_location_error(package),
            invalid_v1_location(package),
            location_framework_mismatch(manifest)
          ]
        end

        def validate_urls(manifest)
          errors = []
          if manifest.terms_conditions_url
            errors << validate_url(manifest.terms_conditions_url, "terms_conditions_url")
          end

          if manifest.author
            errors << validate_url(manifest.author["url"], "author url")
          end
          errors
        end

        def validate_parameters(manifest)
          if manifest.marketing_only?
            marketing_only_errors(manifest)
          else
            [
              parameters_error(manifest),
              invalid_hidden_parameter_error(manifest),
              invalid_type_error(manifest),
              too_many_oauth_parameters(manifest),
              oauth_cannot_be_secure(manifest),
              name_as_parameter_name_error(manifest)
            ]
          end
        end

        def oauth_cannot_be_secure(manifest)
          manifest.parameters.map do |parameter|
            if parameter.type == 'oauth' && parameter.secure
              return ValidationError.new('oauth_parameter_cannot_be_secure')
            end
          end
        end

        def marketing_only_errors(manifest)
          [
            ban_parameters(manifest),
            private_marketing_app_error(manifest)
          ]
        end

        def type_checks(manifest)
          errors = [
            boolean_error(manifest),
            string_error(manifest),
            no_template_format_error(manifest)
          ]
          unless manifest.experiments.is_a?(Hash)
            errors << ValidationError.new(
              :unacceptable_hash,
              field: 'experiments',
              value: manifest.experiments.class.to_s
            )
          end
          whitelist = manifest.domain_whitelist
          unless whitelist.nil? || whitelist.is_a?(Array) && whitelist.all? { |dom| dom.is_a? String }
            errors << ValidationError.new(:unacceptable_array_of_strings, field: 'domainWhitelist')
          end
          parameters = manifest.original_parameters
          unless parameters.nil? || parameters.is_a?(Array)
            errors << ValidationError.new(
              :unacceptable_array,
              field: 'parameters',
              value: parameters.class.to_s
            )
          end
          errors
        end

        def string_error(manifest)
          manifest_strings = %i[
            default_locale
            version
            framework_version
            remote_installation_url
            terms_conditions_url
            google_analytics_code
          ]
          errors = manifest_strings.map do |field|
            validate_string(manifest.public_send(field), field)
          end

          if manifest.author
            author_strings = %w[name email url]
            errors << (author_strings.map do |field|
              validate_string(manifest.author[field], "author #{field}")
            end)
          end
          errors
        end

        def boolean_error(manifest)
          booleans = %i[requirements_only marketing_only single_install signed_urls private]
          errors = []
          RUBY_TO_JSON.each do |ruby, json|
            if booleans.include? ruby
              errors << validate_boolean(manifest.public_send(ruby), json)
            end
          end
          errors.compact
        end

        def validate_string(value, label_for_error)
          unless value.is_a?(String) || value.nil?
            ValidationError.new(:unacceptable_string, field: label_for_error, value: value)
          end
        end

        def validate_boolean(value, label_for_error)
          unless [true, false].include? value
            ValidationError.new(:unacceptable_boolean, field: label_for_error, value: value)
          end
        end

        def check_errors(error_types, collector, *checked_objects)
          error_types.each do |error_type|
            collector << send(error_type, *checked_objects)
          end
        end

        def ban_no_template(manifest)
          return unless manifest.iframe_only?
          no_template_migration_link = 'https://developer.zendesk.com/apps/docs/apps-v2/manifest#location'
          if manifest.no_template? || !manifest.no_template_locations.empty?
            ValidationError.new(:no_template_deprecated_in_v2, link: no_template_migration_link)
          end
        end

        def ban_parameters(manifest)
          ValidationError.new(:no_parameters_required) unless manifest.parameters.empty?
        end

        def ban_location(manifest)
          ValidationError.new(:no_location_required) unless manifest.location_options.empty?
        end

        def ban_framework_version(manifest)
          ValidationError.new(:no_framework_version_required) unless manifest.framework_version.nil?
        end

        def private_marketing_app_error(manifest)
          ValidationError.new(:marketing_only_app_cant_be_private) if manifest.private?
        end

        def oauth_error(manifest)
          return unless manifest.oauth
          oauth_errors = []
          missing = OAUTH_REQUIRED_FIELDS.select do |key|
            manifest.oauth[key].nil? || manifest.oauth[key].empty?
          end

          if missing.any?
            oauth_errors << \
              ValidationError.new('oauth_keys.missing', missing_keys: missing.join(', '), count: missing.length)
          end

          unless manifest.parameters.any? { |param| param.type == 'oauth' }
            oauth_errors << ValidationError.new('oauth_parameter_required',
                                                link: OAUTH_MANIFEST_LINK)
          end
          oauth_errors
        end

        def parameters_error(manifest)
          original = manifest.original_parameters
          unless original.nil? || original.is_a?(Array)
            return ValidationError.new(:parameters_not_an_array)
          end

          return unless manifest.parameters.any?

          para_names = manifest.parameters.map(&:name)
          duplicate_parameters = para_names.select { |name| para_names.count(name) > 1 }.uniq
          unless duplicate_parameters.empty?
            return ValidationError.new(:duplicate_parameters, duplicate_parameters: duplicate_parameters)
          end

          invalid_required = manifest.parameters.map do |parameter|
            validate_boolean(parameter.required, "parameters.#{parameter.name}.required")
          end.compact
          return invalid_required if invalid_required.any?

          invalid_secure = manifest.parameters.map do |parameter|
            validate_boolean(parameter.secure, "parameters.#{parameter.name}.secure")
          end.compact
          return invalid_secure if invalid_secure.any?
        end

        def missing_keys_error(manifest)
          missing = REQUIRED_MANIFEST_FIELDS.map do |ruby_method, manifest_value|
            manifest_value if manifest.public_send(ruby_method).nil?
          end.compact

          missing_keys_validation_error(missing) if missing.any?
        end

        def default_locale_error(manifest, package)
          default_locale = manifest.default_locale
          unless default_locale.nil?
            if default_locale !~ Translations::VALID_LOCALE
              ValidationError.new(:invalid_default_locale, default_locale: default_locale)
            elsif package.translation_files.detect { |f| f.relative_path == "translations/#{default_locale}.json" }.nil?
              ValidationError.new(:missing_translation_file, default_locale: default_locale)
            end
          end
        end

        def missing_location_error(package)
          missing_keys_validation_error(['location']) if package.manifest.location_options.empty?
        end

        def invalid_location_error(package)
          errors = []
          package.manifest.location_options.each do |location_options|
            if location_options.url.is_a?(String) && !location_options.url.empty?
              errors << invalid_location_uri_error(package, location_options)
            elsif location_options.auto_load?
              errors << ValidationError.new(:blank_location_uri, location: location_options.location.name)
            end

            if !([true, false].include? location_options.flexible) && !location_options.flexible.nil?
              errors << invalid_location_flexible_error(location_options)
            end
          end

          Product::PRODUCTS_AVAILABLE.each do |product|
            invalid_locations = package.manifest.unknown_locations(product.name)
            next if invalid_locations.empty?
            errors << ValidationError.new(:invalid_location,
                                          invalid_locations: invalid_locations.join(', '),
                                          host_name: product.name.capitalize,
                                          count: invalid_locations.length)
          end

          package.manifest.unknown_hosts.each do |unknown_host|
            errors << ValidationError.new(:invalid_host, host_name: unknown_host)
          end

          errors
        end

        def invalid_v1_location(package)
          return unless package.manifest.framework_version &&
                        Gem::Version.new(package.manifest.framework_version) < Gem::Version.new('2')

          invalid_locations = package.manifest.location_options
                                     .map(&:location)
                                     .compact
                                     .select(&:v2_only)
                                     .map(&:name)

          unless invalid_locations.empty?
            return ValidationError.new(:invalid_v1_location,
                                       invalid_locations: invalid_locations.join(', '),
                                       count: invalid_locations.length)
          end
        end

        def invalid_location_uri_error(package, location_options)
          path = location_options.url
          return nil if path == ZendeskAppsSupport::Manifest::LEGACY_URI_STUB
          return nil if path.include?('{{setting.')
          validation_error = ValidationError.new(:invalid_location_uri, uri: path)
          uri = URI.parse(path)
          unless uri.absolute? ? valid_absolute_uri?(uri) : valid_relative_uri?(package, uri)
            validation_error
          end
        rescue URI::InvalidURIError
          validation_error
        end

        def invalid_location_flexible_error(location_options)
          flexible_flag = location_options.flexible
          validation_error = ValidationError.new(:invalid_location_flexible_type, flexible: flexible_flag)
          validation_error
        end

        def valid_absolute_uri?(uri)
          uri.scheme == 'https' || uri.host == 'localhost'
        end

        def valid_relative_uri?(package, uri)
          uri.path.start_with?('assets/') && package.has_file?(uri.path)
        end

        def missing_framework_version(manifest)
          missing_keys_validation_error([RUBY_TO_JSON[:framework_version]]) if manifest.framework_version.nil?
        end

        def invalid_version_error(manifest)
          valid_to_serve = AppVersion::TO_BE_SERVED
          target_version = manifest.framework_version

          unless valid_to_serve.include?(target_version)
            return ValidationError.new(:invalid_version,
                                       target_version: target_version,
                                       available_versions: valid_to_serve.join(', '))
          end
        end

        def name_as_parameter_name_error(manifest)
          if manifest.parameters.any? { |p| p.name == 'name' }
            ValidationError.new(:name_as_parameter_name)
          end
        end

        def invalid_hidden_parameter_error(manifest)
          invalid_params = manifest.parameters.select { |p| p.type == 'hidden' && p.required }.map(&:name)

          if invalid_params.any?
            ValidationError.new(:invalid_hidden_parameter,
                                invalid_params: invalid_params.join(', '),
                                count: invalid_params.length)
          end
        end

        def invalid_type_error(manifest)
          invalid_types = []
          manifest.parameters.each do |parameter|
            parameter_type = parameter.type

            invalid_types << parameter_type unless PARAMETER_TYPES.include?(parameter_type)
          end

          if invalid_types.any?
            ValidationError.new(:invalid_type_parameter,
                                invalid_types: invalid_types.join(', '),
                                count: invalid_types.length)
          end
        end

        def too_many_oauth_parameters(manifest)
          oauth_parameters = manifest.parameters.select do |parameter|
            parameter.type == 'oauth'
          end

          if oauth_parameters.count > 1
            ValidationError.new(:too_many_oauth_parameters)
          end
        end

        def missing_keys_validation_error(missing_keys)
          ValidationError.new('manifest_keys.missing',
                              missing_keys: missing_keys.join(', '),
                              count: missing_keys.length)
        end

        def location_framework_mismatch(manifest)
          legacy_locations, iframe_locations = manifest.location_options.partition(&:legacy?)
          if manifest.iframe_only?
            return ValidationError.new(:locations_must_be_urls) unless legacy_locations.empty?
          elsif !iframe_locations.empty?
            return ValidationError.new(:locations_cant_be_urls)
          end
        end

        # TODO: check the app actually runs in included locations
        def no_template_format_error(manifest)
          no_template = manifest.no_template
          return if [false, true].include? no_template
          unless no_template.is_a?(Array) && manifest.no_template_locations.all? { |loc| Location.find_by(name: loc) }
            ValidationError.new(:invalid_no_template)
          end
        end

        def validate_url(value, label_for_error)
          unless value.nil? || value.match(/^https?:\/\//)
            ValidationError.new(:invalid_url, field: label_for_error, value: value)
          end
        end
      end
    end
  end
end
