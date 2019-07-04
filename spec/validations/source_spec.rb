# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do
  let(:files) { [double('AppFile', relative_path: 'abc.js')] }
  let(:manifest_json) { { 'requirementsOnly' => false } }
  let(:package) do
    double('Package', js_files: files,
                      lib_files: [],
                      template_files: [],
                      app_css: '',
                      manifest: ZendeskAppsSupport::Manifest.new(JSON.dump(manifest_json)),
                      locations: { 'zendesk' => { 'ticket_sidebar' => '_legacy' } },
                      iframe_only?: false)
  end

  context 'when requirements only' do
    let(:manifest_json) { { 'requirementsOnly' => true } }

    it 'should have an error when app.js is present' do
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors.first.key).to eql :no_code_for_ifo_notemplate
    end

    it 'should not have an error when app.js is not present' do
      allow(package).to receive(:js_files) { [] }
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors).to be_empty
    end
  end

  context 'when iframe only' do
    before do
      allow(package.manifest).to receive(:iframe_only?) { true }
    end

    context 'when the package includes app.js' do
      before do
        allow(package).to receive(:js_files) { files }
      end

      it 'should have an error' do
        errors = ZendeskAppsSupport::Validations::Source.call(package)
        expect(errors.first.key).to eql :no_code_for_ifo_notemplate
      end
    end

    context 'when the package includes a library' do
      before do
        allow(package).to receive(:js_files) { [double('AppFile', relative_path: 'lib/slapp.js')] }
      end

      it 'should have an error' do
        errors = ZendeskAppsSupport::Validations::Source.call(package)
        expect(errors.first.key).to eql :no_code_for_ifo_notemplate
      end
    end

    context 'when the package includes app.css' do
      before do
        allow(package).to receive(:js_files) { [] }
        allow(package).to receive(:app_css) { 'div {display: none;}' }
      end

      it 'should have an error' do
        errors = ZendeskAppsSupport::Validations::Source.call(package)
        expect(errors.first.key).to eql :no_code_for_ifo_notemplate
      end
    end

    context 'when the package includes a template' do
      before do
        allow(package).to receive(:js_files) { [] }
        allow(package).to receive(:app_css) { '' }
        allow(package).to receive(:template_files) { [ 'templates/layout.hdbs' ] }
      end

      it 'should have an error' do
        errors = ZendeskAppsSupport::Validations::Source.call(package)
        expect(errors.first.key).to eql :no_code_for_ifo_notemplate
      end
    end
  end

  context 'when not requirements only' do
    it 'should have an error when app.js is missing' do
      errors = ZendeskAppsSupport::Validations::Source.call(package)
      expect(errors.first.to_s).to eql 'Could not find app.js'
    end
  end
end
