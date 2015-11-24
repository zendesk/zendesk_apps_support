require 'spec_helper'

describe ZendeskAppsSupport::StylesheetCompiler do

  describe "Compiling an app's stylesheet" do

    let(:color) { "%06x" % rand(2 ** 24 - 1) }
    let(:app_id) { rand(100) }
    let(:asset_name) { 'submit_button.png' }
    let(:asset_url) { "/api/v2/apps/#{app_id}/assets/" }

    let(:css) {
      <<-EOC
a { color: ##{color}; }
.submit {
  background: app-asset-url("#{asset_name}");
}
EOC
    }

    let(:compiler) {
      ZendeskAppsSupport::StylesheetCompiler.new(css, app_id, asset_url)
    }

    subject {
      compiler.compile
    }

    it 'wraps rules in an app-specific selector' do
      expect(subject).to match %r[\.app-#{app_id}\s+a\s*{\s*color:\s*##{color};]m
    end

    it 'evaluates app-asset-url calls' do
      expect(subject).to match %r[\.submit\s*{\s*background:\s*url\("#{asset_url}#{asset_name}"\);]m
    end
  end
end
