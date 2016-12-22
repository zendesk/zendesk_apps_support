# frozen_string_literal: true
require 'uri'

module ZendeskAppsSupport
  module Validations
    module Manifest
      RUBY_TO_JSON = ZendeskAppsSupport::Manifest::RUBY_TO_JSON
      REQUIRED_MANIFEST_FIELDS = RUBY_TO_JSON.select { |k| %i(author default_locale).include? k }.freeze
      OAUTH_REQUIRED_FIELDS    = %w(client_id client_secret authorize_uri access_token_uri).freeze
      PARAMETER_TYPES = ZendeskAppsSupport::Manifest::Parameter::TYPES

      class <<self
        def call(package)
          return [ValidationError.new(:missing_manifest)] unless package.has_file?('manifest.json')
          manifest = package.manifest

          errors = []
          errors << missing_keys_error(manifest)
          errors << oauth_error(manifest)

          if manifest.marketing_only?
            errors << ban_parameters(manifest)
          else
            errors << parameters_error(manifest)
            errors << invalid_hidden_parameter_error(manifest)
            errors << invalid_type_error(manifest)
            errors << name_as_parameter_name_error(manifest)
            errors << no_template_format_error(manifest)
          end
          errors << boolean_error(manifest)
          errors << default_locale_error(manifest, package)

          errors << ban_no_template(manifest) if manifest.iframe_only?

          if manifest.requirements_only? || manifest.marketing_only?
            errors << ban_location(manifest)
            errors << ban_framework_version(manifest)
          else
            errors << missing_location_error(package)
            errors << invalid_location_error(package)
            errors << invalid_v1_location(package)
            errors << missing_framework_version(manifest)
            errors << location_framework_mismatch(manifest)
            errors << invalid_version_error(manifest, package)
          end

          errors.flatten.compact
        rescue JSON::ParserError => e
          return [ValidationError.new(:manifest_not_json, errors: e)]
        end

        private

        def boolean_error(manifest)
          booleans = %i(requirements_only marketing_only single_install signed_urls private)
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

        def ban_no_template(manifest)
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
            if location_options.url && !location_options.url.empty?
              errors << invalid_location_uri_error(package, location_options.url)
            elsif location_options.auto_load?
              errors << ValidationError.new(:blank_location_uri, location: location_options.location.name)
            end
          end

          Product::PRODUCTS_AVAILABLE.each do |product|
            invalid_locations = package.manifest.unknown_locations(product.name)
            next if invalid_locations.empty?
            errors << ValidationError.new(:invalid_location,
                                          invalid_locations: invalid_locations.join(', '),
                                          host_name: product.name,
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

        def missing_framework_version(manifest)
          missing_keys_validation_error([RUBY_TO_JSON[:framework_version]]) if manifest.framework_version.nil?
        end

        def invalid_version_error(manifest, package)
          valid_to_serve = AppVersion::TO_BE_SERVED
          target_version = manifest.framework_version

          if target_version == AppVersion::DEPRECATED
            package.warnings << I18n.t('txt.apps.admin.warning.app_build.deprecated_version')
          end

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

        # TODO: support the new location format in the no_template array and check the app actually runs in
        # included locations
        def no_template_format_error(manifest)
          no_template = manifest.no_template
          return if [false, true].include? no_template
          unless no_template.is_a?(Array) && manifest.no_template_locations.all? { |loc| Location.find_by(name: loc) }
            ValidationError.new(:invalid_no_template)
          end
        end
      end
    end
  end
end
