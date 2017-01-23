# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Validations::Marketplace do
  let(:manifest_extras) { {} }
  let(:manifest) do
    manifest_json = File.read('spec/fixtures/iframe_only_app/manifest.json')
    manifest_hash = JSON.parse(manifest_json, symbolize_names: true).merge(manifest_extras)
    ZendeskAppsSupport::Manifest.new(JSON.dump(manifest_hash))
  end
  let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/iframe_only_app') }
  let(:errors) { ZendeskAppsSupport::Validations::Marketplace.call(package) }

  before do
    allow(package).to receive(:manifest).and_return(manifest)
  end

  context 'with package with symlinks in it' do
    let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/symlinks') }

    it 'raises symlink_in_zip error' do
      expect(errors.first.key).to eq(:symlink_in_zip)
    end
  end

  context 'with the iframe_only_app package' do
    it 'has no errors' do
      expect(errors).to be_empty
    end

    context 'with package with non-whitelisted experiments' do
      let(:manifest_extras) { { experiments: { explodingButtons: true, punnyTickets: true } } }

      it 'raises invalid_experiment validation error' do
        expect(errors[0].key).to eq(:invalid_experiment)
        expect(errors[0].message).to match(/unavailable experiment: explodingButtons/)
        expect(errors[1].message).to match(/unavailable experiment: punnyTickets/)
      end
    end

    context 'with whitelisted experiments' do
      let(:manifest_extras) { { experiments: { hashParams: true } } }

      it 'has no errors' do
        expect(errors).to be_empty
      end
    end
  end
end
