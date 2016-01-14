require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do
  let(:files) { [double('AppFile', relative_path: 'abc.js')] }
  let(:package) do
    double('Package', js_files: files,
                      lib_files: [],
                      manifest_json: { 'requirementsOnly' => false },
                      locations: { 'zendesk' => { 'ticket_sidebar' => '_legacy' } })
  end

  context 'when requirements only' do
    before do
      allow(package).to receive(:manifest_json) { { 'requirementsOnly' => true } }
    end

    it 'should have an error when app.js is present' do
      allow(files.first).to receive(:relative_path) { 'app.js' }
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors.first.key).to eql :no_app_js_required
    end

    it 'should not have an error when app.js is not present' do
      allow(files.first).to receive(:relative_path) { nil }
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors).to be_empty
    end
  end

  context 'when not requirements only' do
    it 'should have an error when app.js is missing' do
      errors = ZendeskAppsSupport::Validations::Source.call(package)
      expect(errors.first.to_s).to eql 'Could not find app.js'
    end
  end

  it 'should have a jslint error when missing semicolon' do
    source = double('AppFile', relative_path: 'app.js', read: 'var a = 1')
    allow(package).to receive(:js_files) { [source] }
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors.first.to_s).to eql "JSHint error in app.js: \n  L1: Missing semicolon."
  end

  it 'should not have a jslint error when using [] notation unnecessarily' do
    source = double('AppFile', relative_path: 'app.js', read: "var a = {}; a['b'] = 0;")
    allow(package).to receive(:js_files) { [source] }
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors).to be_nil
  end

  it 'should have a jslint error when missing semicolon in lib js file' do
    package = ZendeskAppsSupport::Package.new('spec/invalid_app')
    errors  = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors.first.to_s).to eql "JSHint error in lib/invalid.js: \n  L1: Missing semicolon."
  end
end
