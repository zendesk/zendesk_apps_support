require 'spec_helper'

describe ZendeskAppsSupport::Validations::Banner do
  let(:banner_file) { 'banner.png'}
  let(:banner) { double('AppFile', :relative_path => 'assets/banner.png') }
  let(:package) { double('Package', :files => [banner]) }

  before do
    allow(package).to receive(:file_path).and_return(fixture_path(banner_file))
  end

  it 'creates no error on a valid banner' do
    errors = ZendeskAppsSupport::Validations::Banner.call(package)
    expect(errors).to be_empty
  end

  context 'HiDpi file' do
    let(:banner_file) { 'banner_2x.png' }

    it 'creates no error on a valid banner' do
      errors = ZendeskAppsSupport::Validations::Banner.call(package)
      expect(errors).to be_empty
    end
  end

  context 'corrupt file' do
    let(:banner_file) { 'banner_corrupt.png' }

    it 'creates an invalid format error' do
      errors = ZendeskAppsSupport::Validations::Banner.call(package)
      expect(errors.size).to eq(1)
      expect(errors[0].key).to eq('banner.invalid_format')
    end
  end

  context 'invalid format' do
    let(:banner_file) { 'requirements.json' }

    it 'creates an invalid format error' do
      errors = ZendeskAppsSupport::Validations::Banner.call(package)
      expect(errors.size).to eq(1)
      expect(errors[0].key).to eq('banner.invalid_format')
    end
  end

  context 'invalid size' do
    let(:banner_file) { 'banner_invalid_size.png' }

    it 'creates an invalid size error' do
      errors = ZendeskAppsSupport::Validations::Banner.call(package)
      expect(errors.size).to eq(1)
      expect(errors[0].key).to eq('banner.invalid_size')
      expect(errors[0].data).to eq({
        :required_banner_width => ZendeskAppsSupport::Validations::Banner::BANNER_WIDTH,
        :required_banner_height => ZendeskAppsSupport::Validations::Banner::BANNER_HEIGHT
      })
    end
  end
end
