# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe ZendeskAppsSupport::Validations::Source do
  let(:validation_error) { ZendeskAppsSupport::Validations::ValidationError }
  let(:package) { double('Package', js_files: [], template_files: [], app_css: '') }

  after { subject.call(package) }

  context 'when validating requirementsOnly app' do
    before do
      requirements_only_manifest =
        ZendeskAppsSupport::Manifest.new({ requirementsOnly: true, marketingOnly: false }.to_json)
      expect(package).to receive(:manifest).and_return(requirements_only_manifest)
    end

    it 'returns validation error if package contains source files' do
      package.js_files << 'random_js_file.js'

      expect(validation_error).to receive(:new).with(:no_code_for_ifo_notemplate)
    end

    it 'returns no validation error if package has no source files' do
      expect(validation_error).not_to receive(:new)
    end
  end

  context 'when validating marketingOnly app' do
    before do
      marketing_only_manifest =
        ZendeskAppsSupport::Manifest.new({ requirementsOnly: false, marketingOnly: true }.to_json)
      expect(package).to receive(:manifest).and_return(marketing_only_manifest)
    end

    it 'returns validation error if package contains source files' do
      package.template_files << 'random_template.html'

      expect(validation_error).to receive(:new).with(:no_code_for_ifo_notemplate)
    end

    it 'returns no validation error if package has no source files' do
      expect(validation_error).not_to receive(:new)
    end
  end
end
