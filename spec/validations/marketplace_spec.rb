require 'spec_helper'

describe ZendeskAppsSupport::Validations::Marketplace do
  let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/symlinks') }
  let(:errors) { ZendeskAppsSupport::Validations::Marketplace.call(package) }

  it 'should raise error when symlink exists inside the app for the marketplace' do
    expect(errors.first.key).to eq(:symlink_in_zip)
  end
end
