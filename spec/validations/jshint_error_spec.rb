require 'spec_helper'

describe ZendeskAppsSupport::Validations::JSHintValidationError do
  let(:filename) { 'foo.js' }

  context 'with nil errors' do
    let(:errors) { [nil, { 'line' => 12, 'reason' => 'eval is evil' }, nil] }
    let(:error) { ZendeskAppsSupport::Validations::JSHintValidationError.new(filename, errors) }

    it 'ignores nil errors' do
      expect(error.to_s).to match(/eval is evil/)
    end
  end
end
