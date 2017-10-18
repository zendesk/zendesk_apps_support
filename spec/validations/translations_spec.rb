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
  subject { ZendeskAppsSupport::Validations::Translations.call(package) }

  context 'when there are no translation files' do
    let(:translation_files) { [] }
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
