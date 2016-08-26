require 'spec_helper'
require 'faker'
require 'json'

describe ZendeskAppsSupport::Manifest do
  let(:manifest_hash) do
    {
      name: Faker::App.name,
      requirementsOnly: Faker::Boolean.boolean,
      version: Faker::App.version,
      private: true,
      author: {
        name: Faker::App.author,
        email: Faker::Internet.email,
        url: Faker::Internet.url
      },
      frameworkVersion: '2.0',
      singleInstall: Faker::Boolean.boolean,
      signedUrls: Faker::Boolean.boolean,
      noTemplate: false,
      defaultLocale: Faker::Address.country_code,
      location: {
        support: {
          new_ticket_sidebar: Faker::Internet.url,
          top_bar: Faker::Internet.url
        },
        chat: {
          main_panel: Faker::Internet.url
        }
      },
      parameters: [
        {
          name: 'special setting',
          type: ZendeskAppsSupport::Manifest::Parameter::TYPES.sample,
          required: Faker::Boolean.boolean,
          secure: Faker::Boolean.boolean
        }
      ]
    }
  end

  let(:manifest) do
    ZendeskAppsSupport::Manifest.new(JSON.dump(manifest_hash))
  end

  let(:stringify_keys) do
    lambda do |hash|
      return hash unless hash.is_a?(Hash)
      Hash[hash.map do |key, value|
        [key.to_s, stringify_keys[value]]
      end]
    end
  end

  describe 'attr_readers' do
    it 'should return values from the passed in JSON string' do
      expect(manifest.requirements_only).to eq manifest_hash[:requirementsOnly]
      expect(manifest.requirements_only?).to eq manifest_hash[:requirementsOnly]
      expect(manifest.version).to eq manifest_hash[:version]
      expect(manifest.author).to eq stringify_keys[manifest_hash[:author]]
      expect(manifest.framework_version).to eq manifest_hash[:frameworkVersion]
      expect(manifest.single_install).to eq manifest_hash[:singleInstall]
      expect(manifest.single_install?).to eq manifest_hash[:singleInstall]
      expect(manifest.signed_urls).to eq manifest_hash[:signedUrls]
      expect(manifest.signed_urls?).to eq manifest_hash[:signedUrls]
      expect(manifest.no_template).to eq manifest_hash[:noTemplate]
      expect(manifest.default_locale).to eq manifest_hash[:defaultLocale]
      expect(manifest.original_locations).to eq stringify_keys[manifest_hash[:location]]
      expect(manifest.oauth).to eq manifest_hash[:oauth]
      expect(manifest.original_parameters).to eq manifest_hash[:parameters].map(&stringify_keys)
    end
  end

  describe '#private?' do
    context 'when the manifest says private is true' do
      it 'returns true' do
        expect(manifest.private?).to be_truthy
      end
    end

    context 'when the manifest says private is false' do
      before do
        manifest_hash[:private] = false
      end
      it 'returns false' do
        expect(manifest.private?).to be_falsey
      end
    end

    context 'when the manifest omits private' do
      before do
        manifest_hash.delete(:private) { |key| raise "Manifest should have had #{key}" }
      end
      it 'returns true' do
        expect(manifest.private?).to be_truthy
      end
    end
  end

  describe '#parameters' do
    it 'returns a correct Parameter object' do
      expect(manifest.parameters.map(&:class).uniq).to eq [ZendeskAppsSupport::Manifest::Parameter]
      parameter = manifest.parameters.first
      expect(parameter.name).to eq manifest_hash[:parameters][0][:name]
      expect(parameter.type).to eq manifest_hash[:parameters][0][:type]
      expect(parameter.required).to eq manifest_hash[:parameters][0][:required]
      expect(parameter.secure).to eq manifest_hash[:parameters][0][:secure]
    end
  end

  describe '#no_template?' do
    context 'when noTemplate is a boolean in the manifest' do
      it 'returns true when noTemplate is true' do
        manifest_hash[:noTemplate] = true
        expect(manifest.no_template?).to be_truthy
      end

      it 'returns false when noTemplate is false' do
        manifest_hash[:noTemplate] = false
        expect(manifest.no_template?).to be_falsey
      end
    end
    context 'when noTemplate is an array of locations' do
      it 'returns false' do
        manifest_hash[:noTemplate] = ['new_ticket_sidebar', 'nav_bar']
        expect(manifest.no_template?).to be_falsey
      end
    end
  end

  describe '#no_template_locations' do
    context 'when noTemplate is a boolean in the manifest' do
      it 'returns true when noTemplate is true' do
        manifest_hash[:noTemplate] = true
        expect(manifest.no_template_locations).to be_truthy
      end

      it 'returns empty array when noTemplate is false' do
        manifest_hash[:noTemplate] = false
        expect(manifest.no_template_locations).to eq []
      end
    end
    context 'when noTemplate is an array of locations' do
      let(:no_template_locations) { ['new_ticket_sidebar', 'nav_bar'] }
      it 'returns the array of locations' do
        manifest_hash[:noTemplate] = no_template_locations
        expect(manifest.no_template_locations).to eq(no_template_locations)
      end
    end
  end

  describe '#single_install' do
    context 'when singleInstall is missing from the manifest' do
      it 'returns false' do
        manifest_hash.delete(:singleInstall) { |key| raise "Manifest should have had #{key}" }
        expect(manifest.single_install).to eq false
      end
    end
  end

  describe '#signed_urls' do
    context 'when signedUrls is missing from the manifest' do
      it 'returns false' do
        manifest_hash.delete(:signedUrls) { |key| raise "Manifest should have had #{key}" }
        expect(manifest.signed_urls).to eq false
      end
    end
  end

  describe '#location?' do
    context 'when locations are not supplied in the manifest' do
      before do
        manifest_hash.delete(:location) { |key| raise "Manifest should have had #{key}" }
      end
      it 'returns false' do
        expect(manifest.location?).to be_falsey
      end
    end

    context 'when locations are supplied as a string' do
      before do
        manifest_hash[:location] = 'ticket_sidebar'
      end
      it 'returns true' do
        expect(manifest.location?).to be_truthy
      end
    end

    context 'when locations are supplied as an array' do
      before do
        manifest_hash[:location] = %w(ticket_sidebar top_bar)
      end
      it 'returns true' do
        expect(manifest.location?).to be_truthy
      end
    end

    context 'when locations are supplied as an object' do
      it 'returns true' do
        expect(manifest.location?).to be_truthy
      end
    end
  end

  describe '#locations' do
    it 'supports strings' do
      manifest_hash[:location] = 'ticket_sidebar'
      location_object = manifest.locations
      expect(location_object).to eq('support' => { 'ticket_sidebar' => '_legacy' })
    end

    it 'supports arrays' do
      manifest_hash[:location] = %w(🔔 🃏)
      location_object = manifest.locations
      expect(location_object).to eq('support' => { '🃏' => '_legacy', '🔔' => '_legacy' })
    end

    it 'supports objects' do
      location_object = manifest.locations

      expect(location_object).to eq stringify_keys[manifest_hash[:location]]
    end

    it 'canonicalises zendesk to support' do
      manifest_hash[:location] = stringify_keys[{
        zendesk: {
          ticket_sidebar: 'https://my-site.org/'
        },
        chat: {
          main_panel: 'https://your-site.org/'
        }
      }]

      expect(manifest.locations).to eq(
        'support' => {
          'ticket_sidebar' => 'https://my-site.org/'
        },
        'chat' => {
          'main_panel' => 'https://your-site.org/'
        }
      )
    end

    it 'canonicalises zopim to chat' do
      manifest_hash[:location] = stringify_keys[{
        zendesk: {
          ticket_sidebar: 'https://my-site.org/'
        },
        zopim: {
          main_panel: 'https://your-site.org/'
        }
      }]

      expect(manifest.locations).to eq(
        'support' => {
          'ticket_sidebar' => 'https://my-site.org/'
        },
        'chat' => {
          'main_panel' => 'https://your-site.org/'
        }
      )
    end

    it 'works when not present' do
      manifest_hash.delete(:location) { |key| raise "Manifest should have had #{key}" }
      location_object = manifest.locations
      expect(location_object).to eq('support' => {})
    end

    it 'raises an error for duplicate locations' do
      manifest_hash[:location] = %w(background background)
      expect { manifest.locations }.to raise_error(/Duplicate reference in manifest: "background"/)
    end
  end

  describe '#iframe_only?' do
    it 'returns false for an app that has a framework version less than 2' do
      manifest_hash[:frameworkVersion] = '1.0'
      expect(manifest.iframe_only?).to be_falsey
    end

    it 'returns true for an app that has framework version equal to 2' do
      manifest_hash[:frameworkVersion] = '2.0'
      expect(manifest.iframe_only?).to be_truthy
    end

    it 'returns true for an app that has framework version equal greater than 2' do
      manifest_hash[:frameworkVersion] = '2.3'
      expect(manifest.iframe_only?).to be_truthy
    end
  end
end
