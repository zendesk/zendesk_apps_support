require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do
  let(:files) { [double('AppFile', relative_path: 'abc.js')] }
  let(:package) do
    double('Package', js_files: files,
                      lib_files: [],
                      template_files: [],
                      app_css: '',
                      manifest_json: { 'requirementsOnly' => false },
                      locations: { 'zendesk' => { 'ticket_sidebar' => '_legacy' } },
                      iframe_only?: false)
  end

  context 'when requirements only' do
    before do
      allow(package).to receive(:manifest_json) { { 'requirementsOnly' => true } }
    end

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
      allow(package).to receive(:iframe_only?) { true }
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

    # please keep this weird string syntax, my code editor (atom) wants to remove
    # the trailing space, failing the spec
    expect(errors.first.to_s).to eql "JSHint errors in lib/invalid.js: \n"\
"  L4: Expected an assignment or function call and instead saw an expression.
  L4: Missing semicolon.
  L6: Avoid arguments.caller.
  L7: Avoid arguments.callee.
  L13: 'y' is already defined.
  L15: Missing semicolon.
  L9: 'bla' is not defined."
  end

  context 'when it\'s an ES6 app' do
    it 'should be valid' do
      package = ZendeskAppsSupport::Package.new('spec/app_es6')
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      expect(errors).to be nil
    end
  end
end
