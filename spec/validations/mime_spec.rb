# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::Mime do
  let(:subject) { ZendeskAppsSupport::Validations::Mime }
  let(:package) { double('Package', files: []) }

  def add_to_package(pathname)
    relative_path = pathname.split('/').last
    allow(package).to receive(:path_to).with(relative_path).and_return(pathname)
    app_file = ZendeskAppsSupport::AppFile.new(package, relative_path)

    package.files << app_file
  end

  context 'when file extension and content subtype are not supported' do
    it 'returns error when content subtype is block listed' do
      add_to_package('spec/fixtures/mime_types_tests/standard_pdf.pdf')
      errors = subject.call(package)
      expect(errors).to eq(['Unsupported MIME Type(s) detected in standard_pdf.pdf.'])
    end

    it 'returns error when app_file.extension is block listed' do
      add_to_package('spec/fixtures/mime_types_tests/standard_doc.doc')

      errors = subject.call(package)
      expect(errors).to eq(['Unsupported MIME Type(s) detected in standard_doc.doc.'])
    end

    it 'returns error when block listed file is renamed with a safe extension' do
      add_to_package('spec/fixtures/mime_types_tests/zip_pretending_tobe.html')

      errors = subject.call(package)
      expect(errors).to eq(['Unsupported MIME Type(s) detected in zip_pretending_tobe.html.'])
    end

    it 'returns error listing all file names that are block listed' do
      add_to_package('spec/fixtures/mime_types_tests/standard_doc.doc')
      add_to_package('spec/fixtures/mime_types_tests/standard_zip.zip')

      errors = subject.call(package)
      expect(errors.first).to eq(
        'Unsupported MIME Type(s) detected in standard_doc.doc, standard_zip.zip.'
      )
    end
  end

  context 'when file extension and content subtype are supported' do
    it 'returns no errors' do
      add_to_package('spec/fixtures/mime_types_tests/standard_html.html')
      add_to_package('spec/fixtures/mime_types_tests/standard_css.css')

      errors = subject.call(package)
      expect(errors).to be_nil
    end
  end
end
