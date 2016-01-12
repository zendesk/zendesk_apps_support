require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do
  context 'when requirements only' do
    it 'should have an error when app.js is present' do
      files = [double('AppFile', relative_path: 'app.js')]
      package = double('Package', js_files: files, lib_files: [], manifest_json: { 'requirementsOnly' => true })
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors.first.key).to eql :no_app_js_required
    end

    it 'should not have an error when app.js is not present' do
      files = [double('AppFile', relative_path: nil)]
      package = double('Package', js_files: files, lib_files: [], manifest_json: { 'requirementsOnly' => true })
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors).to be_empty
    end
  end

  context 'when not requirements only' do
    it 'should have an error when app.js is missing' do
      files = [double('AppFile', relative_path: 'abc.js')]
      package = double('Package', js_files: files, lib_files: [], manifest_json: { 'requirementsOnly' => false })
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors.first.to_s).to eql 'Could not find app.js'
    end
  end

  it 'should have a jslint error when missing semicolon' do
    source = double('AppFile', relative_path: 'app.js', read: 'var a = 1')
    package = double('Package', root: '.', js_files: [source], lib_files: [], manifest_json: { 'requirementsOnly' => false })
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors.first.to_s).to eql "JSHint error in app.js: \n  L1: Missing semicolon."
  end

  it 'should not have a jslint error when using [] notation unnecessarily' do
    source = double('AppFile', relative_path: 'app.js', read: "var a = {}; a['b'] = 0;")
    package = double('Package', root: '.', js_files: [source], lib_files: [], manifest_json: { 'requirementsOnly' => false })
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors).to be_nil
  end

  it 'should have a jslint error when missing semicolon in lib js file' do
    package = ZendeskAppsSupport::Package.new('spec/invalid_app')
    errors  = ZendeskAppsSupport::Validations::Source.call(package)

    expect(errors.first.to_s).to eql "JSHint errors in lib/invalid.js: 
  L4: Expected an assignment or function call and instead saw an expression.
  L4: Missing semicolon.
  L6: Avoid arguments.caller.
  L7: Avoid arguments.callee.
  L13: 'y' is already defined.
  L15: Missing semicolon.
  L9: 'bla' is not defined."
  end
end
