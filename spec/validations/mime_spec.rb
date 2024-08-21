# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::Validations::Mime do
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

      expect(ZendeskAppsSupport::Validations::ValidationError)
        .to receive(:new)
        .with(:unsupported_mime_type_detected, file_names: 'standard_pdf.pdf', count: 1)

      subject.call(package)
    end

    it 'returns error when app_file.extension is block listed' do
      add_to_package('spec/fixtures/mime_types_tests/standard_doc.doc')

      expect(ZendeskAppsSupport::Validations::ValidationError)
        .to receive(:new)
        .with(:unsupported_mime_type_detected, file_names: 'standard_doc.doc', count: 1)

      subject.call(package)
    end

    it 'returns error when block listed file is renamed with a safe extension' do
      add_to_package('spec/fixtures/mime_types_tests/zip_pretending_tobe.html')

      expect(ZendeskAppsSupport::Validations::ValidationError)
        .to receive(:new)
        .with(:unsupported_mime_type_detected, file_names: 'zip_pretending_tobe.html', count: 1)

      subject.call(package)
    end

    it 'returns error listing all file names that are block listed' do
      add_to_package('spec/fixtures/mime_types_tests/standard_doc.doc')
      add_to_package('spec/fixtures/mime_types_tests/standard_zip.zip')

      expect(ZendeskAppsSupport::Validations::ValidationError)
        .to receive(:new)
        .with(:unsupported_mime_type_detected, file_names: 'standard_doc.doc, standard_zip.zip', count: 2)

      subject.call(package)
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
