# frozen_string_literal: true

require 'spec_helper'
require 'faker'

describe ZendeskAppsSupport::Validations::Translations do
  let(:location) do
    {
      support: {
        new_ticket_sidebar: {
          url: Faker::Internet.url
        },
        top_bar: {
          url: Faker::Internet.url
        }
      },
      chat: {
        chat_sidebar: {
          url: Faker::Internet.url
        }
      }
    }
  end

  let(:private_app?) { true }

  let(:manifest_hash) do
    {
      name: Faker::App.name,
      version: Faker::App.version,
      private: private_app?,
      author: {
        name: Faker::App.author,
        email: Faker::Internet.email,
        url: Faker::Internet.url
      },
      frameworkVersion: '2.0',
      defaultLocale: Faker::Address.country_code,
      location: location
    }
  end

  let(:manifest) { ZendeskAppsSupport::Manifest.new(JSON.dump(manifest_hash)) }
  let(:package) { double('Package', files: translation_files, manifest: manifest) }
  let(:opts) { {} }
  subject { ZendeskAppsSupport::Validations::Translations.call(package, opts) }

  context 'when there are no translation files' do
    let(:translation_files) { [] }
    it 'should be valid' do
      expect(subject).to be_empty
    end
  end

  context 'when translations for all languages are present' do
    let(:translation_files) do
      languages = ["af", "af-za", "ajp-ps", "am", "apc-ps", "ar", "ar-ae",
                   "ar-BH", "ar-eg", "ar-IL", "ar-KW", "ar-LB", "ar-MA",
                   "ar-OM", "ar-ps", "ar-QA", "ar-SA", "as-in", "ay-bo", "az",
                   "be", "bg", "bg-bg", "bn", "bn-in", "bs", "ca", "ca-es",
                   "cs", "cs-cz", "cy", "da", "da-dk", "de", "de-at", "de-be",
                   "de-ch", "de-de", "de-dk", "de-it", "de-lu", "de-ro", "el",
                   "el-cy", "el-gr", "en-001", "en-150", "en-ae", "en-am",
                   "en-at", "en-au", "en-az", "en-BA", "en-be", "en-bg",
                   "en-bh", "en-bo", "en-BZ", "en-ca", "en-ch", "en-co",
                   "en-cr", "en-cy", "en-cz", "en-DE", "en-dk", "en-ec",
                   "en-ee", "en-eg", "en-es", "en-FI", "en-FR", "en-gb",
                   "en-ge", "en-GH", "en-gi", "en-gr", "en-gu", "en-hk",
                   "en-hn", "en-HR", "en-hu", "en-id", "en-ie", "en-il",
                   "en-in", "en-is", "en-it", "en-jp", "en-KE", "en-kr",
                   "en-KW", "en-kz", "en-lb", "en-lr", "en-lt", "en-lu",
                   "en-lv", "en-MA", "en-ME", "en-mt", "en-mx", "en-my",
                   "en-nl", "en-no", "en-nz", "en-om", "en-pe", "en-ph",
                   "en-pk", "en-pl", "en-pr", "en-ps", "en-pt", "en-qa",
                   "en-ro", "en-RS", "en-ru", "en-RW", "en-SA", "en-se",
                   "en-sg", "en-SI", "en-sk", "en-th", "en-TN", "en-TR",
                   "en-tw", "en-ua", "en-UG", "en-US", "en-vn", "en-za", "es",
                   "es-001", "es-419", "es-ar", "es-bo", "es-cl", "es-co",
                   "es-cr", "es-DO", "es-ec", "es-es", "es-GT", "es-hn",
                   "es-mx", "es-NI", "es-PA", "es-pe", "es-pr", "es-PY",
                   "es-SV", "es-us", "es-UY", "es-ve", "et", "et-ee", "eu",
                   "eu-es", "fa", "fa-AF", "fi", "fi-FI", "fil", "fil-ph", "fo",
                   "fo-dk", "fr", "fr-002", "fr-be", "fr-ca", "fr-ch", "fr-ci",
                   "fr-fr", "fr-it", "fr-lu", "fr-ma", "ga", "ga-ie", "gl",
                   "gl-es", "gu", "gu-in", "he", "he-IL", "hi", "hi-in", "hr",
                   "hr-HR", "hu", "hu-hu", "hu-ro", "hu-sk", "hu-ua", "hy",
                   "id", "id-id", "ikt", "is", "it", "it-ch", "it-it", "iu",
                   "ja", "ja-JP", "jv-id", "ka", "kk", "kl-dk", "km", "kn",
                   "kn-in", "ko", "ko-kr", "ks-in", "ku", "ky", "lt", "lt-lt",
                   "lt-lv", "lv", "lv-lv", "mi-nz", "mk", "ml", "ml-in", "mn",
                   "mr", "mr-in", "ms", "ms-my", "mt", "my", "nb", "nb-no",
                   "ne", "nl", "nl-be", "nl-id", "nl-nl", "nn", "nn-no", "no",
                   "nso-za", "or-in", "pa", "pa-in", "pl", "pl-cz", "pl-lt",
                   "pl-pl", "pl-ua", "ps", "ps-AF", "pt", "pt-br", "pt-pt",
                   "qu-bo", "qu-ec", "qu-pe", "rn-BI", "ro", "ro-bg", "ro-ro",
                   "ro-sk", "ro-ua", "ru", "ru-ee", "ru-kz", "ru-lt", "ru-lv",
                   "ru-ua", "sa-in", "sd-in", "si", "sk", "sk-cz", "sk-sk",
                   "sl", "sl-SI", "so", "sq", "sr", "sr-me", "st-za", "sv",
                   "sv-se", "sw", "sw-RW", "ta", "ta-in", "te", "te-in", "tg",
                   "th", "tk", "tl", "tn-za", "tr", "tr-bg", "ts-za", "uk",
                   "uk-sk", "uk-ua", "ur", "ur-in", "ur-PK", "uz", "vi",
                   "vi-vn", "xh", "xh-za", "zh-cn", "zh-hk", "zh-mo", "zh-sg",
                   "zh-tw", "zu-za"]
      languages.map do |lang|
        double('AppFile', relative_path: "translations/#{lang}.json", read: read_fixture_file('valid_en.json'))
      end
    end
    it 'should be valid' do
      expect(subject).to be_empty
    end
  end

  context 'when there is file with invalid JSON' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en.json', read: '}')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/JSON/)
    end
  end

  context 'when there is file with JSON representing a non-Object' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en.json', read: '"foo bar"')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/JSON/)
    end
  end

  context 'when there is a file with an invalid locale for a name' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en-US-1.json', read: '{}')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/locale/)
    end
  end

  context 'when there is a file with a valid locale containing valid JSON' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en-US.json', read: '{}')]
    end

    it 'should be valid' do
      expect(subject.length).to eq(0)
    end
  end

  context 'when there is a en.json' do
    context 'required keys are missing' do
      let(:translation_files) do
        [double('AppFile',
                relative_path: 'translations/en.json',
                read: read_fixture_file('invalid_en.json'),
                to_s: 'translations/en.json')]
      end

      it 'should report the error' do
        expect(subject.length).to eq(1)
        expect(subject[0].to_s).to match(/Missing required key from/)
      end
    end

    context 'whenthe name key is present' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en.json', read: read_fixture_file('valid_en.json'))]
      end

      it 'should be valid' do
        expect(subject.length).to eq(0)
      end
    end

    context 'for a public app' do
      let(:private_app?) { false }

      context 'given only the name key' do
        let(:translation_files) do
          [double('AppFile', relative_path: 'translations/en.json', read: read_fixture_file('valid_en.json'))]
        end

        it 'should report the error' do
          expect(subject.length).to eq(1)
          expect(subject[0].to_s).to match(/Missing required key from/)
        end

        describe 'when the skip_marketplace_translations option is set to true' do
          let(:translation_files) do
            [double('AppFile',
                    relative_path: 'translations/en.json',
                    read: read_fixture_file('name_only_en.json'),
                    to_s: 'translations/en.json')]
          end
          let(:opts) { { skip_marketplace_translations: true } }

          it 'should be valid' do
            expect(subject.length).to eq(0)
          end
        end
      end

      context 'given all mandatory keys' do
        let(:translation_files) do
          [double('AppFile', relative_path: 'translations/en.json', read: read_fixture_file('valid_en_public.json'))]
        end

        it 'should be valid' do
          expect(subject.length).to eq(0)
        end
      end
    end

    context 'for an empty translations object' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en.json', read: '{}')]
      end

      it 'reports missing keys' do
        expect(subject[0].to_s).to match(%r{Missing required key from translations/en.json})
      end
    end

    context 'when multiple products are specified' do
      context 'for a public app' do
        let(:private_app?) { false }

        context 'when only some mandatory keys are specified on the product level' do
          let(:translation_files) do
            [
              double(
                'AppFile',
                relative_path: 'translations/en.json',
                read: read_fixture_file('invalid_en_multi_product_mixed.json')
              )
            ]
          end

          it 'should report the error' do
            expect(subject[0].to_s).to match(%r{Missing required key from translations/en.json for Support})
          end
        end

        context 'when all mandatory keys are specified on the product level' do
          let(:translation_files) do
            [
              double(
                'AppFile',
                relative_path: 'translations/en.json',
                read: read_fixture_file('valid_en_multi_product.json')
              )
            ]
          end

          it 'should be valid' do
            expect(subject.length).to eq(0)
          end

          context 'when the product keys in en.json do not match the products specified in the manifest' do
            let(:location) do
              {
                support: {
                  new_ticket_sidebar: { url: Faker::Internet.url }
                }
              }
            end

            it 'should report the error' do
              expect(subject[0].to_s).to match(
                /Products in manifest \(Support\) do not match products in translations \(Support, Chat\)/
              )
            end
          end
        end
      end
    end
  end

  context 'validate translation format when "parameters" is defined inside "app"' do
    context 'when the leaf nodes do not have a "label"' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/pt-br.json', read: read_fixture_file('invalid_pt-br.json'))]
      end

      it 'should report the error' do
        expect(subject.length).to eq(1)
        expect(subject[0].to_s).to \
          eq('Missing required key label on leaf description from translations/pt-br.json')
      end
    end

    context 'when the leaf nodes have "label"' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/pt-br.json', read: read_fixture_file('valid_pt-br.json'))]
      end

      it 'should be valid' do
        expect(subject.length).to eq(0)
      end
    end
  end

  context 'validate translation format when "package" is defined inside "app"' do
    context 'all the leaf nodes have defined "title" and "value"' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en-US.json', read: read_fixture_file('valid_en-US.json'))]
      end

      it 'should be valid' do
        expect(subject.length).to eq(0)
      end
    end

    context 'when the "title" field is not defined on one leaf node' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en-US.json', read: read_fixture_file('invalid_en-US.json'))]
      end

      it 'should report the error' do
        expect(subject.length).to eq(1)
        expect(subject[0].to_s).to match(/is invalid for translation/)
      end
    end
  end
end
