require 'json'
require 'uri'

module ZendeskAppsSupport
  module Validations
    module Manifest
      RUBY_TO_JSON = ZendeskAppsSupport::Manifest::RUBY_TO_JSON
      REQUIRED_MANIFEST_FIELDS = RUBY_TO_JSON.select { |k| %i(author default_locale).include? k }.freeze
      OAUTH_REQUIRED_FIELDS    = %w(client_id client_secret authorize_uri access_token_uri).freeze

      class <<self
        def call(package)
          return [ValidationError.new(:missing_manifest)] unless package.has_file?('manifest.json')
          manifest = package.manifest

          errors = []
          check_errors(%i(missing_keys_error oauth_error parameters_error invalid_hidden_parameter_error
                          invalid_type_error name_as_parameter_name_error no_template_format_error boolean_error), errors, manifest)
          check_errors(%i(default_locale_error), errors, manifest, package)

          if manifest.requirements_only?
            check_errors(%i(ban_location ban_framework_version), errors, manifest)
          else
            check_errors(%i(missing_location_error invalid_location_error), errors, package)
            check_errors(%i(duplicate_location_error missing_framework_version
                            location_framework_mismatch), errors, manifest)
            check_errors(%i(invalid_version_error), errors, manifest, package)
          end

          errors.flatten.compact
        rescue JSON::ParserError => e
          return [ValidationError.new(:manifest_not_json, errors: e)]
        end

        private

        def boolean_error(manifest)
          booleans = %i(requirements_only single_install signed_urls private)
          errors = []
          RUBY_TO_JSON.each do |ruby, json|
            if booleans.include? ruby
              errors << validate_boolean(manifest.public_send(ruby), json)
            end
          end
          errors.compact
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

        def ban_location(manifest)
          ValidationError.new(:no_location_required) if manifest.location?
        end

        def ban_framework_version(manifest)
          ValidationError.new(:no_framework_version_required) unless manifest.framework_version.nil?
        end

        def oauth_error(manifest)
          return unless manifest.oauth

          missing = OAUTH_REQUIRED_FIELDS.select do |key|
            manifest.oauth[key].nil? || manifest.oauth[key].empty?
          end

          if missing.any?
            ValidationError.new('oauth_keys.missing', missing_keys: missing.join(', '), count: missing.length)
          end
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
              ValidationError.new(:invalid_default_locale, defaultLocale: default_locale)
            elsif package.translation_files.detect { |file| file.relative_path == "translations/#{default_locale}.json" }.nil?
              ValidationError.new(:missing_translation_file, defaultLocale: default_locale)
            end
          end
        end

        def missing_location_error(package)
          missing_keys_validation_error(['location']) unless package.manifest.location?
        end

        def invalid_location_error(package)
          errors = []
          manifest_locations = package.manifest.locations
          manifest_locations.find do |host, locations|
            # CRUFT: remove when support for legacy names are deprecated
            product = Product.find_by(legacy_name: host) || Product.find_by(name: host)
            error = if product.nil?
              ValidationError.new(:invalid_host, host_name: host)
            elsif (invalid_locations = locations.keys - Location.where(product_code: product.code).map(&:name)).any?
              ValidationError.new(:invalid_location,
                                  invalid_locations: invalid_locations.join(', '),
                                  host_name: host,
                                  count: invalid_locations.length)
            end

            # abort early for invalid host or location name
            if error
              errors << error
              break
            end

            locations.values.each do |path|
              errors << invalid_location_uri_error(package, path)
            end
          end
          errors
        end

        def invalid_location_uri_error(package, path)
          return nil if path == ZendeskAppsSupport::Manifest::LEGACY_URI_STUB
          validation_error = ValidationError.new(:invalid_location_uri, uri: path)
          uri = URI.parse(path)
          unless uri.absolute? ? valid_absolute_uri?(uri) : valid_relative_uri?(package, uri)
            validation_error
          end
        rescue URI::InvalidURIError
          validation_error
        end

        def valid_absolute_uri?(uri)
          uri.scheme == 'https' || uri.host == 'localhost'
        end

        def valid_relative_uri?(package, uri)
          uri.path.start_with?('assets/') && package.has_file?(uri.path)
        end

        def duplicate_location_error(manifest)
          locations           = *manifest.locations
          duplicate_locations = *locations.select { |location| locations.count(location) > 1 }.uniq

          unless duplicate_locations.empty?
            ValidationError.new(:duplicate_location, duplicate_locations: duplicate_locations.join(', '), count: duplicate_locations.length)
          end
        end

        def missing_framework_version(manifest)
          missing_keys_validation_error(['frameworkVersion']) if manifest.framework_version.nil?
        end

        def invalid_version_error(manifest, package)
          valid_to_serve = AppVersion::TO_BE_SERVED
          target_version = manifest.framework_version

          if target_version == AppVersion::DEPRECATED
            package.warnings << I18n.t('txt.apps.admin.warning.app_build.deprecated_version')
          end

          unless valid_to_serve.include?(target_version)
            return ValidationError.new(:invalid_version, target_version: target_version, available_versions: valid_to_serve.join(', '))
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
            ValidationError.new(:invalid_hidden_parameter, invalid_params: invalid_params.join(', '), count: invalid_params.length)
          end
        end

        def invalid_type_error(manifest)
          invalid_types = []
          manifest.parameters.each do |parameter|
            parameter_type = parameter.type

            invalid_types << parameter_type unless ZendeskAppsSupport::Manifest::Parameter::TYPES.include?(parameter_type)
          end

          if invalid_types.any?
            ValidationError.new(:invalid_type_parameter,
                                invalid_types: invalid_types.join(', '),
                                count: invalid_types.length)
          end
        end

        def missing_keys_validation_error(missing_keys)
          ValidationError.new('manifest_keys.missing', missing_keys: missing_keys.join(', '), count: missing_keys.length)
        end

        def location_framework_mismatch(manifest)
          locations = manifest.locations
          iframe_locations = locations.values.any? do |location_hash|
            location_hash.values.any? { |url| url != ZendeskAppsSupport::Manifest::LEGACY_URI_STUB }
          end
          legacy_locations = (!iframe_locations && manifest.location?) || locations.values.any? do |location_hash|
            location_hash.values.any? { |url| url == ZendeskAppsSupport::Manifest::LEGACY_URI_STUB }
          end
          if manifest.iframe_only?
            return ValidationError.new(:locations_must_be_urls) if legacy_locations
          elsif iframe_locations
            return ValidationError.new(:locations_cant_be_urls)
          end
        end

        # TODO: support the new location format in the no_template array and check the app actually runs in
        # included locations
        def no_template_format_error(manifest)
          no_template = manifest.no_template
          return if [false, true, nil].include? no_template
          unless no_template.is_a?(Array) && manifest.no_template_locations.all? { |loc| Location.find_by(name: loc) }
            ValidationError.new(:invalid_no_template)
          end
        end
      end
    end
  end
end
