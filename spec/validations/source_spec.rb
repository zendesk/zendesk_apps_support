require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do

  context 'when requirements only' do
    it 'should have an error when app.js is present' do
      files = [mock('AppFile', :relative_path => 'app.js')]
      package = mock('Package', :files => files, :lib_files => [], :requirements_only => true)
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      errors.first.key.should eql :no_app_js_required
    end

    it 'should not have an error when app.js is not present' do
      files = [mock('AppFile', :relative_path => nil)]
      package = mock('Package', :files => files, :lib_files => [], :requirements_only => true)
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      errors.should be_empty
    end
  end

  context 'when not requirements only' do
    it 'should have an error when app.js is missing' do
      files = [mock('AppFile', :relative_path => 'abc.js')]
      package = mock('Package', :files => files, :lib_files => [], :requirements_only => false)
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      errors.first.to_s.should eql 'Could not find app.js'
    end
  end

  it 'should have a jslint error when missing semicolon' do
    source = mock('AppFile', :relative_path => 'app.js', :read => "var a = 1")
    package = mock('Package', :root => '.', :files => [source], :lib_files => [], :requirements_only => false)
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    errors.first.to_s.should eql "JSHint error in app.js: \n  L1: Missing semicolon."
  end

  it 'should not have a jslint error when using [] notation unnecessarily' do
    source = mock('AppFile', :relative_path => 'app.js', :read => "var a = {}; a['b'] = 0;")
    package = mock('Package', :root => '.', :files => [source], :lib_files => [], :requirements_only => false)
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    errors.should be_nil
  end

  it 'should have a jslint error when missing semicolon in lib js file' do
    package = ZendeskAppsSupport::Package.new('spec/invalid_app')
    errors  = ZendeskAppsSupport::Validations::Source.call(package)

    errors.first.to_s.should eql "JSHint error in lib/invalid.js: \n  L1: Missing semicolon."
  end
end
