# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::AppFile do
  before do
    package = double('Package', path_to: Pathname('spec/app/templates/layout.hdbs'))
    @file = ZendeskAppsSupport::AppFile.new(package, 'layout.hdbs')
  end

  describe '=~' do
    it 'tests against the relative path of the file' do
      expect(@file).to match(/layout/)
    end
  end

  describe 'read' do
    it 'reads file content' do
      expect(@file.read).to match(/<header>/)
    end
  end

  describe 'to_s' do
    it 'returns file name' do
      expect(@file.to_s).to eq('layout.hdbs')
    end
  end

  describe 'extension' do
    it 'returns file extension' do
      expect(@file.extension).to eq('.hdbs')
    end
  end
end
