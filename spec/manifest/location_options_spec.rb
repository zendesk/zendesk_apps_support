# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Manifest::LocationOptions do
  let(:location) { ZendeskAppsSupport::Location::LOCATIONS_AVAILABLE.first }
  let(:options) { { 'url' => '_legacy', 'autoHide' => true, 'autoLoad' => false, 'signed' => true } }
  subject(:location_options) { described_class.new(location, options) }

  it 'reads in options correctly' do
    expect(location_options.location).to be location
    expect(location_options.auto_load).to be false
    expect(location_options.auto_hide).to be true
    expect(location_options.signed).to be true
    expect(location_options.legacy).to be true
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
    end
  end

  context 'when url is not a string' do
    let(:options) { { 'url' => true } }
    it 'coerces to string' do
      expect(location_options.url).to eq('true')
    end
  end
end
