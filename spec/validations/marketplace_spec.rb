require 'spec_helper'

describe ZendeskAppsSupport::Validations::Marketplace do
  let(:errors) { ZendeskAppsSupport::Validations::Marketplace.call(package) }

  context 'with package with symlinks in it' do
    let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/symlinks') }

    it 'should raise error when symlink exists inside the app for the marketplace' do
      expect(errors.first.key).to eq(:symlink_in_zip)
    end
  end

  context 'with package with non-whitelisted experiments' do
    let(:manifest) { ZendeskAppsSupport::Manifest.new(JSON.dump(manifest_hash)) }
    let(:manifest_hash) do
      json = JSON.parse(File.read('spec/fixtures/iframe_only_app/manifest.json'))
      json['experiments'] = { explodingButtons: true, punnyTickets: true }
      json
    end
    let(:package) do
      package = ZendeskAppsSupport::Package.new('spec/fixtures/iframe_only_app')
      allow(package).to receive(:manifest).and_return(manifest)
      package
    end

    it 'raises invalid_experiment validation error' do
      expect(errors[0].key).to eq(:invalid_experiment)
      expect(errors[0].message).to match(/unavailable experiment: explodingButtons/)
      expect(errors[1].message).to match(/unavailable experiment: punnyTickets/)
    end
  end

end
