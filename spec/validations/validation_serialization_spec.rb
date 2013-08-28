require 'zendesk_apps_support'
require 'json'

describe ZendeskAppsSupport::Validations::ValidationError do

  ValidationError = ZendeskAppsSupport::Validations::ValidationError

  it 'symbolizes the keys in its data' do
    error = ValidationError.new(:foo, 'bar' => 'baz')
    error.data[:bar].should == 'baz'
  end

  describe '#to_json' do
    let(:key)   { 'foo.bar' }
    let(:data)  { { 'baz' => 'quux' } }
    let(:error) { ValidationError.new(key, data) }
    subject     { MultiJson.encode(error) }

    it do
      should == MultiJson.encode({
                  'class' => error.class.to_s,
                  'key'   => error.key,
                  'data'  => error.data
                })
    end
  end

  describe '.from_hash' do

    subject { ValidationError.from_hash(hash) }

    context 'for a generic error' do
      let(:hash) do
        {
          'class' => 'ZendeskAppsSupport::Validations::ValidationError',
          'key'   => 'foo.bar.baz',
          'data'  => { 'quux' => 'yargle' }
        }
      end

      it { should be_a(ValidationError) }

      its(:key) { should == 'foo.bar.baz' }

      its(:data) { should == { :quux => 'yargle' } }
      its(:data) { should}
    end

    context 'for a JSHint error' do
      let(:hash) do
        {
          'class'         => 'ZendeskAppsSupport::Validations::JSHintValidationError',
          'file'          => 'foo.js',
          'jshint_errors' => [ { 'line' => 55, 'reason' => 'Yuck' } ]
        }
      end

      it { should be_a(ZendeskAppsSupport::Validations::JSHintValidationError) }

      its(:key) { should == :jshint }

      its(:jshint_errors) do
        should == [ { 'line' => 55, 'reason' => 'Yuck' } ]
      end
    end

    context 'for a non-ValidationError hash' do
      let(:hash) do
        {
          :foo => 'bar'
        }
      end

      it 'raises a DeserializationError' do
        lambda { subject }.should raise_error(ValidationError::DeserializationError)
      end
    end

  end

  describe '.from_json' do

    it 'decodes a JSON hash and passes it to .from_hash' do
      ValidationError.should_receive(:from_hash).with('foo' => 'bar')
      ValidationError.from_json(MultiJson.encode({ 'foo' => 'bar' }))
    end

    it 'raises a DeserializationError when passed non-JSON' do
      lambda {
        ValidationError.from_json('}}}')
      }.should raise_error(ValidationError::DeserializationError)
    end

  end

end
