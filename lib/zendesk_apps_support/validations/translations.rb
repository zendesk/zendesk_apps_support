# frozen_string_literal: true
require 'jshintrb'
require 'json'

module ZendeskAppsSupport
  module Validations
    module Translations
      TRANSLATIONS_PATH = %r{^translations/(.*)\.json$}
      VALID_LOCALE      = /^[a-z]{2}(-\w{2,3})?$/
      MANDATORY_KEYS = %w(name description installation_instructions long_description).freeze

      class TranslationFormatError < StandardError
      end

      class << self
        def call(package)
          package.files.each_with_object([]) do |file, errors|
            path_match = TRANSLATIONS_PATH.match(file.relative_path)
            next unless path_match
            errors << locale_error(file, path_match[1]) << json_error(file)
            errors << validate_marketplace_content(file, package) if errors.compact.empty?
          end.compact
        end

        private

        def locale_error(file, locale)
          return nil if VALID_LOCALE =~ locale
          ValidationError.new('translation.invalid_locale', file: file.relative_path)
        end

        def json_error(file)
          json = JSON.parse(file.read)
          if json.is_a?(Hash)
            if json['app'] && json['app']['package']
              json['app'].delete('package')
              begin
                validate_translation_format(json)
                return
              rescue TranslationFormatError => e
                ValidationError.new('translation.invalid_format', field: e.message)
              end
            end
          else
            ValidationError.new('translation.not_json_object', file: file.relative_path)
          end
        rescue JSON::ParserError => e
          ValidationError.new('translation.not_json', file: file.relative_path, errors: e)
        end

        def validate_marketplace_content(file, package)
          return if file.relative_path != 'translations/en.json'

          json = JSON.parse(file.read)
          product_names = Product::PRODUCTS_AVAILABLE.map(&:name)
          present_product_keys = json['app'].keys & product_names

          if present_product_keys.empty?
            # validate all mandatory keys are there
            if (json['app'].keys & MANDATORY_KEYS).sort != MANDATORY_KEYS.sort
              missing_keys = MANDATORY_KEYS - json['app'].keys
              return ValidationError.new(
                'translation.missing_required_key',
                file: file.relative_path,
                missing_key: missing_keys.join(', ')
              )
            end
          else
            # validate product keys match manifest products
            manifest_products = package.manifest.products.map(&:name)
            if present_product_keys.sort != manifest_products.sort
              return ValidationError.new(
                'translation.products_do_not_match_manifest_products',
                file: file.relative_path,
                translation_products: present_product_keys.join(', '),
                manifest_products: manifest_products.join(', ')
              )
            end

            # validate each product key has required keys under it
            present_product_keys.each do |product|
              next unless (json['app'][product].keys & MANDATORY_KEYS).sort != MANDATORY_KEYS.sort
              missing_keys = MANDATORY_KEYS - json['app'][product].keys
              return ValidationError.new(
                'translation.missing_required_key_for_product',
                file: file.relative_path,
                product: product,
                missing_key: missing_keys.join(', ')
              )
            end
          end
          nil
        end

        def validate_translation_format(json)
          json.keys.each do |key|
            raise TranslationFormatError, "'#{key}': '#{json[key]}'" unless json[key].is_a? Hash

            if json[key].keys.sort == BuildTranslation::I18N_KEYS &&
               json[key][BuildTranslation::I18N_TITLE_KEY].class == String &&
               json[key][BuildTranslation::I18N_VALUE_KEY].class == String
              next
            else
              validate_translation_format(json[key])
            end
          end
        end
      end
    end
  end
end
