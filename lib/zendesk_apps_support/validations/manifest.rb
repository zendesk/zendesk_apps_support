require 'multi_json'

module ZendeskAppsSupport
  module Validations
    module Manifest

      REQUIRED_MANIFEST_FIELDS = %w( author defaultLocale ).freeze
      OAUTH_REQUIRED_FIELDS    = %w( client_id client_secret authorize_uri access_token_uri ).freeze
      LOCATIONS_AVAILABLE      = %w( top_bar nav_bar ticket_sidebar new_ticket_sidebar user_sidebar ).freeze
      TYPES_AVAILABLE          = %W( text password checkbox url number multiline hidden ).freeze

      class <<self
        def call(package)
          manifest = package.files.find { |f| f.relative_path == 'manifest.json' }

          return [ValidationError.new(:missing_manifest)] unless manifest

          manifest = MultiJson.load(manifest.read)

          [].tap do |errors|
            errors << missing_keys_error(manifest)
            errors << default_locale_error(manifest, package)
            errors << oauth_error(manifest)
            errors << parameters_error(manifest)
            errors << invalid_hidden_parameter_error(manifest)
            errors << invalid_type_error(manifest)
            errors << name_as_parameter_name_error(manifest)

            if manifest['requirementsOnly']
              package.requirements_only = true

              errors << ban_location(manifest)
              errors << ban_framework_version(manifest)
            else
              errors << missing_location_error(package)
              errors << invalid_location_error(manifest)
              errors << duplicate_location_error(manifest)
              errors << missing_framework_version(manifest)
              errors << invalid_version_error(manifest, package)
            end

            errors.compact!
          end
        rescue MultiJson::DecodeError => e
          return [ValidationError.new(:manifest_not_json, :errors => e)]
        end

        private

        def ban_location(manifest)
          ValidationError.new(:no_location_required) unless manifest['location'].nil?
        end

        def ban_framework_version(manifest)
          ValidationError.new(:no_framework_version_required) unless manifest['frameworkVersion'].nil?
        end

        def oauth_error(manifest)
          return unless manifest['oauth']

          missing = OAUTH_REQUIRED_FIELDS.select do |key|
            manifest['oauth'][key].nil? || manifest['oauth'][key].empty?
          end

          if missing.any?
            ValidationError.new('oauth_keys.missing', :missing_keys => missing.join(', '), :count => missing.length)
          end

        end

        def parameters_error(manifest)
          return unless manifest['parameters']

          unless manifest['parameters'].kind_of?(Array)
            return ValidationError.new(:parameters_not_an_array)
          end

          para_names = manifest['parameters'].collect{|para| para['name']}
          duplicate_parameters = para_names.select {|name| para_names.count(name) > 1}.uniq
          unless duplicate_parameters.empty?
            return ValidationError.new(:duplicate_parameters, :duplicate_parameters => duplicate_parameters)
          end
        end

        def missing_keys_error(manifest)
          missing = REQUIRED_MANIFEST_FIELDS.select do |key|
            manifest[key].nil?
          end

          missing_keys_validation_error(missing) if missing.any?
        end

        def default_locale_error(manifest, package)
          default_locale = manifest['defaultLocale']
          if !default_locale.nil?
            if default_locale !~ Translations::VALID_LOCALE
              ValidationError.new(:invalid_default_locale, :defaultLocale => default_locale)
            elsif package.translation_files.detect { |file| file.relative_path == "translations/#{default_locale}.json" }.nil?
              ValidationError.new(:missing_translation_file, :defaultLocale => default_locale)
            end
          end
        end

        def missing_location_error(package)
          missing_keys_validation_error(['location']) unless package.has_location?
        end

        def invalid_location_error(manifest)
          invalid_locations = [*manifest['location']] - LOCATIONS_AVAILABLE
          unless invalid_locations.empty?
            ValidationError.new(:invalid_location, :invalid_locations => invalid_locations.join(', '), :count => invalid_locations.length)
          end
        end

        def duplicate_location_error(manifest)
          locations           = *manifest['location']
          duplicate_locations = *locations.select { |location| locations.count(location) > 1 }.uniq

          unless duplicate_locations.empty?
            ValidationError.new(:duplicate_location, :duplicate_locations => duplicate_locations.join(', '), :count => duplicate_locations.length)
          end
        end

        def missing_framework_version(manifest)
          missing_keys_validation_error(['frameworkVersion']) if manifest['frameworkVersion'].nil?
        end

        def invalid_version_error(manifest, package)
          valid_to_serve = AppVersion::TO_BE_SERVED
          target_version = manifest['frameworkVersion']

          if target_version == AppVersion::DEPRECATED
            package.warnings << I18n.t('txt.apps.admin.warning.app_build.deprecated_version')
          end

          unless valid_to_serve.include?(target_version)
            return ValidationError.new(:invalid_version, :target_version => target_version, :available_versions => valid_to_serve.join(', '))
          end
        end

        def name_as_parameter_name_error(manifest)
          if manifest['parameters'].kind_of?(Array)
            if manifest['parameters'].any? { |p| p['name'] == 'name' }
              ValidationError.new(:name_as_parameter_name)
            end
          end
        end

        def invalid_hidden_parameter_error(manifest)
          invalid_params = []

          if manifest.has_key?('parameters')
            invalid_params = manifest['parameters'].select { |p| p['type'] == 'hidden' && p['required'] }.map { |p| p['name'] }
          end

          if invalid_params.any?
            ValidationError.new(:invalid_hidden_parameter, :invalid_params => invalid_params.join(', '), :count => invalid_params.length)
          end
        end

        def invalid_type_error(manifest)
          return unless manifest['parameters'].kind_of?(Array)

          invalid_types = []

          manifest["parameters"].each do |parameter|
            parameter_type = parameter.fetch("type", '')

            invalid_types << parameter_type unless TYPES_AVAILABLE.include?(parameter_type)
          end

          if invalid_types.any?
            ValidationError.new(:invalid_type_parameter, :invalid_types => invalid_types.join(', '), :count => invalid_types.length)
          end
        end

        def missing_keys_validation_error(missing_keys)
          ValidationError.new('manifest_keys.missing', :missing_keys => missing_keys.join(', '), :count => missing_keys.length)
        end

      end
    end
  end
end
