# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::AppVersion do
  describe 'the current version' do
    subject do
      ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::CURRENT)
    end

    it { is_expected.to be_frozen }
    it { is_expected.to be_present }
    it { is_expected.to be_servable }
    it { is_expected.to be_valid_for_update }
    it { is_expected.to be_valid_for_create }
    it { is_expected.not_to be_blank }
    it { is_expected.not_to be_deprecated }
    it { is_expected.not_to be_obsolete }
    it { is_expected.to eq(ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::CURRENT)) }
    it { is_expected.not_to eq(ZendeskAppsSupport::AppVersion.new('0.2')) }

    describe '#to_s' do
      subject { super().to_s }
      it { is_expected.to eq(ZendeskAppsSupport::AppVersion::CURRENT) }
    end

    describe '#to_json' do
      subject { super().to_json }
      it { is_expected.to eq(ZendeskAppsSupport::AppVersion::CURRENT.to_json) }
    end
  end

  describe 'the deprecated version' do
    before do
      stub_const('ZendeskAppsSupport::AppVersion::DEPRECATED', ['1.0'])
      stub_const('ZendeskAppsSupport::AppVersion::TO_BE_SERVED', ['1.0'])
    end

    subject do
      ZendeskAppsSupport::AppVersion.new('1.0')
    end

    it { is_expected.to be_frozen }
    it { is_expected.to be_present }
    it { is_expected.to be_servable }
    it { is_expected.not_to be_valid_for_update }
    it { is_expected.not_to be_valid_for_create }
    it { is_expected.not_to be_blank }
    it { is_expected.to be_deprecated }
    it { is_expected.not_to be_obsolete }
    it { is_expected.to eq(ZendeskAppsSupport::AppVersion.new('1.0')) }
    it { is_expected.not_to eq(ZendeskAppsSupport::AppVersion.new('0.2')) }

    describe '#to_s' do
      subject { super().to_s }
      it { is_expected.to eq('1.0') }
    end

    describe '#to_json' do
      subject { super().to_json }
      it { is_expected.to eq('"1.0"') }
    end
  end

  describe 'a really old version' do
    subject do
      ZendeskAppsSupport::AppVersion.new('0.1')
    end

    it { is_expected.to be_frozen }
    it { is_expected.to be_present }
    it { is_expected.not_to be_servable }
    it { is_expected.not_to be_valid_for_update }
    it { is_expected.not_to be_valid_for_create }
    it { is_expected.not_to be_blank }
    it { is_expected.not_to be_deprecated }
    it { is_expected.to be_obsolete }
    it { is_expected.to eq(ZendeskAppsSupport::AppVersion.new('0.1')) }
    it { is_expected.not_to eq(ZendeskAppsSupport::AppVersion.new('0.2')) }

    describe '#to_s' do
      subject { super().to_s }
      it { is_expected.to eq('0.1') }
    end

    describe '#to_json' do
      subject { super().to_json }
      it { is_expected.to eq('0.1'.to_json) }
    end
  end
end
