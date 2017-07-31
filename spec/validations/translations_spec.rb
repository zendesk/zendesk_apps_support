# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Validations::Translations do
  let(:package) { double('Package', files: translation_files) }
  subject { ZendeskAppsSupport::Validations::Translations.call(package) }

  context 'when there are no translation files' do
    let(:translation_files) { [] }
    it 'should be valid' do
      expect(subject).to be_empty
    end
  end

  context 'when there is file with invalid JSON' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en.json', read: '}')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/JSON/)
    end
  end

  context 'when there is file with JSON representing a non-Object' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en.json', read: '"foo bar"')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/JSON/)
    end
  end

  context 'when there is a file with an invalid locale for a name' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en-US-1.json', read: '{}')]
    end

    it 'should report the error' do
      expect(subject.length).to eq(1)
      expect(subject[0].to_s).to match(/locale/)
    end
  end

  context 'when there is a file with a valid locale containing valid JSON' do
    let(:translation_files) do
      [double('AppFile', relative_path: 'translations/en-US.json', read: '{}')]
    end

    it 'should be valid' do
      expect(subject.length).to eq(0)
    end
  end

  context 'when there is a en.json' do
    context 'required keys are missing' do
      let(:translation_files) do
        [double('AppFile',
                relative_path: 'translations/en.json',
                read: read_fixture_file('invalid_en.json'),
                to_s: 'translations/en.json')]
      end

      it 'should report the error' do
        expect(subject.length).to eq(1)
        expect(subject[0].to_s).to match(/Missing required key from/)
      end
    end

    context 'required keys are present' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en.json', read: read_fixture_file('valid_en.json'))]
      end

      it 'should be valid' do
        expect(subject.length).to eq(0)
      end
    end
  end

  context 'validate translation format when "package" is defined inside "app"' do
    context 'all the leaf nodes have defined "title" and "value"' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en-US.json', read: read_fixture_file('valid_en-US.json'))]
      end

      it 'should be valid' do
        expect(subject.length).to eq(0)
      end
    end

    context 'when the "title" field is not defined on one leaf node' do
      let(:translation_files) do
        [double('AppFile', relative_path: 'translations/en-US.json', read: read_fixture_file('invalid_en-US.json'))]
      end

      it 'should report the error' do
        expect(subject.length).to eq(1)
        expect(subject[0].to_s).to match(/is invalid for translation/)
      end
    end
  end
end
