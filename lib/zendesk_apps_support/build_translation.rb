# frozen_string_literal: true

module ZendeskAppsSupport
  module BuildTranslation
    I18N_TITLE_KEY = 'title'
    I18N_VALUE_KEY = 'value'
    I18N_KEYS      = [I18N_TITLE_KEY, I18N_VALUE_KEY].freeze

    def to_flattened_namespaced_hash(hash, target_key = nil, prefix = nil)
      hash.each_with_object({}) do |(key, value), result|
        key = [prefix, key].compact.join('.')
        if value.is_a?(Hash)
          if target_key && translation_hash?(value)
            result[key] = value[target_key]
          else
            result.update(to_flattened_namespaced_hash(value, target_key, key))
          end
        else
          result[key] = value
        end
      end
    end

    def remove_zendesk_keys(scope, translations = {})
      scope.each_key do |key|
        context = scope[key]

        if context.is_a?(Hash)

          if translation_hash?(context)
            translations[key] = context[I18N_VALUE_KEY]
          else
            translations[key] ||= {}
            translations[key] = remove_zendesk_keys(context, translations[key])
          end

        else
          translations[key] = context
        end
      end

      translations
    end

    private

    def translation_hash?(hash)
      hash.keys.sort == I18N_KEYS
    end
  end
end
