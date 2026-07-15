# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Manifest::LocationOptions do
  let(:location) { ZendeskAppsSupport::Location::LOCATIONS_AVAILABLE.first }
  let(:options) do
    {
      'url' => '_legacy',
      'autoHide' => true,
      'autoLoad' => false,
      'signed' => true,
      'size' => { 'height' => '220px' }
    }
  end
  subject(:location_options) { described_class.new(location, options) }

  it 'reads in options correctly' do
    expect(location_options.location).to be location
    expect(location_options.auto_load).to be false
    expect(location_options.auto_hide).to be true
    expect(location_options.signed).to be true
    expect(location_options.legacy).to be true
    expect(location_options.size).to eq({ 'height' => '220px' })
  end

  it 'provides question mark aliases' do
    expect(location_options.signed?).to be true
    expect(location_options.legacy?).to be true
  end

  context 'with default options' do
    let(:options) { {} }
    it 'sets defaults' do
      expect(location_options.auto_load).to be true
      expect(location_options.auto_hide).to be false
      expect(location_options.signed).to be false
      expect(location_options.legacy).to be false
      expect(location_options.object_types).to be_nil
    end
  end

  context 'with object_types' do
    let(:location) do
      ZendeskAppsSupport::Location::LOCATIONS_AVAILABLE.find do |l|
        l.name == ZendeskAppsSupport::Location::CUSTOM_OBJECT_RECORD_SIDEBAR_LOCATION
      end
    end
    let(:options) do
      {
        'objectTypes' => %w[car truck]
      }
    end

    it 'reads object_types correctly' do
      expect(location_options.object_types).to eq(%w[car truck])
    end
  end

  context 'with object_types on a non-custom_object_record_sidebar location' do
    let(:options) do
      {
        'objectTypes' => %w[car truck]
      }
    end

    it 'preserves object_types for validation' do
      expect(location_options.object_types).to eq(%w[car truck])
    end
  end
end
