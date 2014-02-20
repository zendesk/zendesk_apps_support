require 'spec_helper'

describe ZendeskAppsSupport::Validations::Source do

  context 'when requirements only' do
    it 'should have an error when app.js is present' do
      files = [mock('AppFile', :relative_path => 'app.js')]
      package = mock('Package', :files => files, :is_requirements_only? => true)
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      errors.first.to_s.should eql 'Having app.js present while requirements only is true'
    end
  end

  context 'when not requirements only' do
    it 'should have an error when app.js is missing' do
      files = [mock('AppFile', :relative_path => 'abc.js')]
      package = mock('Package', :files => files, :is_requirements_only? => false)
      errors = ZendeskAppsSupport::Validations::Source.call(package)

      errors.first.to_s.should eql 'Could not find app.js'
    end
  end

  it 'should have a jslint error when missing semicolon' do
    source = mock('AppFile', :relative_path => 'app.js', :read => "var a = 1")
    package = mock('Package', :files => [source], :is_requirements_only? => false)
    errors = ZendeskAppsSupport::Validations::Source.call(package)

    errors.first.to_s.should eql "JSHint error in app.js: \n  L1: Missing semicolon."
  end

end
