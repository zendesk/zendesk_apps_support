# frozen_string_literal: true

require 'spec_helper'

json_base = '{"name":"App","author":{},"location":{},"version":"1.0"}'
html_base = '<html><body><script src="zaf_sdk.js"></script></body></html>'
js_base = 'const client = ZAFClient.init();'

describe ZendeskAppsSupport::Validations::Svg do
  let(:mock_json) { json_base }
  let(:mock_html) { html_base }
  let(:mock_js) { js_base }
  let(:subject) { ZendeskAppsSupport::Validations::Secrets }
  let(:manifest_json) { double('AppFile', relative_path: 'manifest.json', read: mock_json) }
  let(:iframe_html) { double('AppFile', relative_path: 'assets/iframe.html', read: mock_html) }
  let(:app_js) { double('AppFile', relative_path: 'assets/app.js', read: mock_js) }
  let(:files) { [manifest_json, iframe_html, app_js] }
  let(:package) { double('Package', text_files: files, warnings: []) }

  context 'a single text file containing generic secret keyword(s)' do
    let(:mock_json) { json_base.gsub('}', '"api_key":"abc123"') }
    it 'raises an appropriate generic secret warning' do
      subject.call(package)
      expect(package.warnings.length).to eq(1)
      expect(package.warnings[0]).to include('secrets found', 'manifest.json')
    end

    it 'do not raise any errors' do
      errors = subject.call(package)
      expect(errors).to be_empty
    end
  end

  context 'multiple text files containing generic secret keyword(s)' do
    let(:mock_json) { json_base.gsub('}', '"secret":"abc123"') }
    let(:mock_html) { html_base.gsub('</script>', '</script><script>const api_key = "abc123"</script>') }
    it 'raise a single generic grouped warning' do
      subject.call(package)
      expect(package.warnings.length).to eq(1)
      expect(package.warnings[0]).to include('secrets found', 'manifest.json', 'assets/iframe.html')
    end

    it 'do not raise any errors' do
      errors = subject.call(package)
      expect(errors).to be_empty
    end
  end

  context 'text files containing application specific secrets or tokens' do
    let(:mock_json) { json_base.gsub('}', '"github":"d41d8cd98f00b204e9800998ecf8427e"') }
    let(:mock_js) { js_base.gsub(';', 'const foo = "AKIAIOSFODNN7EXAMPLE";') }

    it 'raise specific warnings for each individual file' do
      subject.call(package)
      expect(package.warnings[0]).to include('Github Token found', 'manifest.json')
      expect(package.warnings[1]).to include('AWS Access Key ID found', 'assets/app.js')
    end

    it 'do not raise any errors' do
      errors = subject.call(package)
      expect(errors).to be_empty
    end
  end
end
