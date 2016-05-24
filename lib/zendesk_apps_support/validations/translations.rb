require 'json'

module ZendeskAppsSupport
  module Validations
    module Translations
      TRANSLATIONS_PATH = %r{^translations/(.*)\.json$}
      VALID_LOCALE      = /^[a-z]{2}(-\w{2,3})?$/

      class TranslationFormatError < StandardError
      end

      class << self
        def call(package)
          package.files.inject([]) do |errors, file|
            if path_match = TRANSLATIONS_PATH.match(file.relative_path)
              errors << locale_error(file, path_match[1]) << json_error(file)
            end
            errors
          end.compact
        end

        private

        def locale_error(file, locale)
          return nil if VALID_LOCALE =~ locale
          ValidationError.new('translation.invalid_locale', file: file.relative_path)
        end

        def json_error(file)
          json = JSON.load(file.read)
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
            fail TranslationFormatError.new("'#{key}': '#{json[key]}'") unless json[key].is_a? Hash

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
