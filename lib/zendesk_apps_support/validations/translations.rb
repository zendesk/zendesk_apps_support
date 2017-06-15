# frozen_string_literal: true
require 'jshintrb'
require 'json'

module ZendeskAppsSupport
  module Validations
    module Translations
      TRANSLATIONS_PATH = %r{^translations/(.*)\.json$}
                          # from https://support.zendesk.com/api/v2/locales/agent.json
                          # manually added 'en'
      VALID_LOCALES     = %w{bg cs da de en en-CA en-GB en-US es es-419 es-ES fi fr fr-CA it ja ko nl no pl pt pt-BR ro ru sv tr uk zh-CN zh-TW}.freeze

      class TranslationFormatError < StandardError
      end

      class << self
        def call(package)
          package.files.each_with_object([]) do |file, errors|
            path_match = TRANSLATIONS_PATH.match(file.relative_path)
            if path_match
              errors << locale_error(file, path_match[1]) << json_error(file)
            end
          end.compact
        end

        private

        def locale_error(file, locale)
          return nil if VALID_LOCALES.include?(locale)
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
