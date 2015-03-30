require 'spec_helper'

describe ZendeskAppsSupport::Validations::ValidationError do
  ValidationError = ZendeskAppsSupport::Validations::ValidationError

  it 'symbolizes the keys in its data' do
    error = ValidationError.new(:foo, 'bar' => 'baz')
    expect(error.data[:bar]).to eq('baz')
  end

  describe '#to_json' do
    let(:key)   { 'foo.bar' }
    let(:data)  { { 'baz' => 'quux' } }
    let(:error) { ValidationError.new(key, data) }
    subject     { JSON.generate(error) }

    it do
      is_expected.to eq(JSON.generate(
        'class' => error.class.to_s,
        'key'   => error.key,
        'data'  => error.data
      ))
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

      it { is_expected.to be_a(ValidationError) }

      describe '#key' do
        subject { super().key }
        it { is_expected.to eq('foo.bar.baz') }
      end

      describe '#data' do
        subject { super().data }
        it { is_expected.to eq(quux: 'yargle') }
      end
    end

    context 'for a JSHint error' do
      let(:hash) do
        {
          'class'         => 'ZendeskAppsSupport::Validations::JSHintValidationError',
          'file'          => 'foo.js',
          'jshint_errors' => [{ 'line' => 55, 'reason' => 'Yuck' }]
        }
      end

      it { is_expected.to be_a(ZendeskAppsSupport::Validations::JSHintValidationError) }

      describe '#key' do
        subject { super().key }
        it { is_expected.to eq(:jshint) }
      end

      describe '#jshint_errors' do
        subject { super().jshint_errors }
        it do
          is_expected.to eq([{ 'line' => 55, 'reason' => 'Yuck' }])
        end
      end
    end

    context 'for a non-ValidationError hash' do
      let(:hash) do
        {
          foo: 'bar'
        }
      end

      it 'raises a DeserializationError' do
        expect { subject }.to raise_error(ValidationError::DeserializationError)
      end
    end
  end

  describe '.from_json' do
    it 'decodes a JSON hash and passes it to .from_hash' do
      expect(ValidationError).to receive(:from_hash).with('foo' => 'bar')
      ValidationError.from_json(JSON.generate('foo' => 'bar'))
    end

    it 'raises a DeserializationError when passed non-JSON' do
      expect do
        ValidationError.from_json('}}}')
      end.to raise_error(ValidationError::DeserializationError)
    end
  end
end
