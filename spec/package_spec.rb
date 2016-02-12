require 'spec_helper'
require 'tmpdir'

describe ZendeskAppsSupport::Package do
  before do
    @package = ZendeskAppsSupport::Package.new('spec/app')

    lib_files_original_method = @package.method(:lib_files)
    allow(@package).to receive(:lib_files) do |*args, &block|
      lib_files_original_method.call(*args, &block).sort_by(&:relative_path)
    end
  end

  describe 'files' do
    it 'should return all the files within the app folder excluding files in tmp folder' do
      files = %w(app.css app.js assets/logo-small.png assets/logo.png lib/a.js lib/a.txt
                 lib/nested/b.js manifest.json templates/layout.hdbs translations/en.json translations/nl.json)
      expect(@package.files.map(&:relative_path)).to match_array(files)
    end

    it 'should error out when manifest is missing' do
      @package = ZendeskAppsSupport::Package.new('spec/app_nomanifest')
      err = @package.validate
      expect(err.first.class).to eq(ZendeskAppsSupport::Validations::ValidationError)
      expect(err.first.to_s).to eq('Could not find manifest.json')
    end
  end

  describe 'template_files' do
    it 'should return all the files in the templates folder within the app folder' do
      expect(@package.template_files.map(&:relative_path)).to eq(%w(templates/layout.hdbs))
    end
  end

  describe 'translation_files' do
    it 'should return all the files in the translations folder within the app folder' do
      expect(@package.translation_files.map(&:relative_path).sort).to eq(%w(translations/en.json translations/nl.json))
    end
  end

  describe 'lib_files' do
    it 'should return all the javascript files in the lib folder within the app folder' do
      expect(@package.lib_files.map(&:relative_path)).to eq(%w(lib/a.js lib/nested/b.js))
    end
  end

  describe 'commonjs_modules' do
    it 'should return an object with name value pairs containing the path and code' do
      expect(@package.send(:commonjs_modules)).to eq(
        'a.js' => "var a = {\n  name: 'This is A'\n};\n\nmodule.exports = a;\n",
        'nested/b.js' => "var b = {\n  name: 'This is B'\n};\n\nmodule.exports = b;\n"
      )
    end
  end

  describe 'manifest_json' do
    it 'should return manifest json' do
      manifest = @package.manifest_json
      expect(manifest['name']).to eq('ABC')
      expect(manifest['author']['name']).to eq('John Smith')
      expect(manifest['author']['email']).to eq('john@example.com')
      expect(manifest['defaultLocale']).to eq('en')
      expect(manifest['private']).to eq(true)
      expect(manifest['location']).to eq('ticket_sidebar')
      expect(manifest['frameworkVersion']).to eq('0.5')
    end
  end

  describe 'compile_js' do
    it 'should generate js ready for installation' do
      js = @package.compile_js(app_name: "ABC", app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/legacy_app_en.js')
      expect(js).to eq(expected)

      js = @package.compile_js(app_name: "EFG", app_id: 1, assets_dir: 'http://localhost:4567/2/', locale: 'nl')
      expected = File.read('spec/fixtures/legacy_app_nl.js')
      expect(js).to eq(expected)
    end

    it 'should generate js for iframe app installations' do
      @package = ZendeskAppsSupport::Package.new('spec/iframe_only_app')
      js = @package.compile_js(app_name: "ABC", app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/iframe_app.js')
      expect(js).to eq(expected)
    end
  end

  describe 'deep_merge_hash' do
    it 'should merge a simple hash' do
      hash_1   = {'id' => 1}
      hash_2   = {'id' => 2}
      expected = {'id' => 2}
      expect( @package.send(:deep_merge_hash, hash_1, hash_2) ).to eq(expected)
    end

    it 'should merge 2 hashes recursively' do
      hash_1   = {'id' => 1, 'nick' => { label: 'test', gender: 'yes'}}
      hash_2   = {'id' => 2}
      expected = {'id' => 2, 'nick' => { label: 'test', gender: 'yes'}}
      expect( @package.send(:deep_merge_hash, hash_1, hash_2) ).to eq(expected)

      hash_1   = {'id' => 1, 'nick' => { label: 'test', gender: 'yes'}}
      hash_2   = {'id' => 2, 'nick' => 'test'}
      expected = {'id' => 2, 'nick' => 'test'}
      expect( @package.send(:deep_merge_hash, hash_1, hash_2) ).to eq(expected)

      hash_1   = {'id' => 1, 'nick' => { label: { text: 'text', value: 'value'}}}
      hash_2   = {'id' => 2, 'nick' => { label: { text: 'different', option: 3}}}
      expected = {'id' => 2, 'nick' => { label: { text: 'different', value: 'value', option: 3}}}
      expect( @package.send(:deep_merge_hash, hash_1, hash_2) ).to eq(expected)
    end
  end

  let(:manifest) do
    JSON.parse(File.read('spec/bookmarks_app/manifest.json'))
  end

  let(:root) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(root) if Dir.exists?(root)
  end

  def build_app_source(app)
    app_js           = File.read('spec/bookmarks_app/app.js')
    app_css          = File.read('spec/bookmarks_app/app.css')
    main_template    = File.read('spec/bookmarks_app/templates/main.hdbs')
    layout           = nil
    en_json          = File.read('spec/bookmarks_app/translations/en.json')
    logo             = File.read('spec/bookmarks_app/assets/logo.png')
    logo_small       = File.read('spec/bookmarks_app/assets/logo-small.png')
    manifest         = JSON.generate(app[:manifest] || { })
    additional_files = app[:additional_files] || { }

    FileUtils.rm_rf(root) if Dir.exists?(root)

    {
      'manifest.json'         => manifest,
      'app.js'                => app_js,
      'app.css'               => app_css,
      'templates/layout.hdbs' => layout,
      'templates/main.hdbs'   => main_template,
      'translations/en.json'  => en_json,
      'assets/logo.png'       => logo,
      'assets/logo-small.png' => logo_small
    }.merge(additional_files).each do |path, content|
      unless content.nil?
        path = File.join(root, path)
        FileUtils.mkdir_p( File.dirname(path) )
        File.open(path, 'w') { |f| f << content }
      end
    end

    File.join(root)
  end

  let(:source) { build_app_source(manifest: manifest) }

  let(:package) { ZendeskAppsSupport::Package.new(source) }

  def build_app_source_with_files(files)
    build_app_source({
      manifest: manifest,
      additional_files: files
    })
  end

  describe 'market_translations! works as expected' do
    it 'builds an app' do
      expect(package.manifest_json['author']['name']).to eq('Ned Stark')
      expect(package.send(:translations)).to eq({"en"=>{"app"=>{"description"=>"Quickly access bookmarked tickets. Syncs with the iPad app."}, "custom1"=>"The first custom thing"}})
      expect(package.send(:market_translations!, 'en')).to eq({})
      expect(package.send(:translations)).to eq({"en"=>{"app"=>{}, "custom1"=>"The first custom thing"}})
    end

    it 'builds an app with changed manifest' do
      manifest['author']['name'] = 'Olaf'
      expect(package.manifest_json['author']['name']).to eq('Olaf')
    end
  end

  describe 'Reading a manifest' do
    it 'fetches data from the manifest' do
      expect(package.manifest_json['location']).to eq('ticket_sidebar')
      expect(package.manifest_json['defaultLocale']).to eq('en')
      expect(package.manifest_json['version']).to eq('1.5')
      expect(package.manifest_json['frameworkVersion']).to eq('0.5')
      expect(package.manifest_json['remoteInstallationURL']).to eq('https://example.com/install')
      expect(package.manifest_json['termsConditionsURL']).to eq('http://terms.com')

      expect(package.manifest_json['author']).to eq({ 'name' => 'Ned Stark', 'email' => 'ned@winter.com', 'url' => 'http://www.zendesk.com/apps'})
    end
  end

  describe '#translations' do
    let(:description) { 'Quickly access bookmarked tickets. Syncs with the iPad app.' }
    let(:custom1) { 'The first custom thing' }
    context 'with default locale' do
      it 'returns translations' do
        expect(package.send(:translations)).to eq({ 'en'=>{ 'app' => { 'description'=>description }, 'custom1' => custom1 } })
        expect(package.locales).to eq(['en'])
      end

      context 'with zh-cn.json' do
        let (:source) do
          build_app_source_with_files({
            'translations/zh-cn.json' => File.read('spec/translations/zh-cn.json')
          })
        end

        it 'includes en and zh-cn in translations' do
          expect(package.locales).to match_array(['en', 'zh-cn'])
        end

        it 'includes zh-cn in translations' do
          expect(package.send(:translations)['zh-cn'].except('custom1')).to eq(JSON.parse(File.read('spec/translations/zh-cn.json')))
        end

        it 'merges missing keys with the default locale'  do
          expect(package.send(:translations)['zh-cn']['custom1']).to eq(custom1)
        end
      end

      context 'with zh-cn_keyval.json' do
        let (:source) do
          build_app_source_with_files({
            'translations/zh-cn.json' => File.read('spec/translations/zh-cn_keyval.json')
          })
        end

        it 'includes en and zh-cn in translations' do
          expect(package.locales).to match_array(['en', 'zh-cn'])
        end

        it 'removes zendesk-specific keys in translations' do
          expect(package.send(:translations)['zh-cn'].except('custom1')).to eq(JSON.parse(File.read('spec/translations/zh-cn.json')))
        end

        it 'merges missing keys with the default locale'  do
          expect(package.send(:translations)['zh-cn']['custom1']).to eq(custom1)
        end

        it 'removes app.package key' do
          expect(package.send(:translations)['zh-cn']['app']['package']).to be_nil
        end
      end
    end

    context 'without a default locale' do
      let(:manifest) { super().merge('defaultLocale' => nil) }

      it 'returns translations' do
        expect(package.send(:translations)).to eq({ 'en'=>{ 'app' => { 'description'=>description }, 'custom1'=>custom1 } })
        expect(package.locales).to eq(['en'])
      end
    end

  end

  describe '#css' do
    context 'for an app with an app.css' do
      it 'returns the CSS' do
        expect(package.app_css).to eq(File.read('spec/bookmarks_app/app.css'))
      end
    end

    context 'for an app without an app.css' do
      let(:source) { build_app_source(additional_files: { "app.css" => nil }) }

      it 'returns an empty string' do
        expect(package.app_css).to eq('')
      end
    end
  end

  describe '#market_translations!' do
    let(:translations) { { 'app' => { 'name' => 'Some App', 'description' => 'It does something.' } } }
    let(:source) { build_app_source(additional_files: { "translations/en.json" => translations.to_json }) }

    subject { package.market_translations!('en') }

    it 'ignores "name"' do
      expect(subject['name']).to be nil
    end

    it 'ignores "description"' do
      expect(subject['description']).to be nil
    end
  end

  describe '#validate' do
    it 'should not raise error when symlink exists inside the app for outside the marketplace' do
      package = ZendeskAppsSupport::Package.new('spec/fixtures/symlinks')
      expect { package.validate!(marketplace: false) }.to raise_error(ZendeskAppsSupport::Validations::ValidationError)
    end

    it 'should raise error when symlink exists inside the app for the marketplace' do
      package = ZendeskAppsSupport::Package.new('spec/fixtures/symlinks')
      expect { package.validate!(marketplace: true) }.to raise_error(ZendeskAppsSupport::Validations::ValidationError)
    end

    it 'should raise error when symlink exists inside the app for the marketplace' do
      package = ZendeskAppsSupport::Package.new('spec/fixtures/symlinks')
      expect { package.validate! }.to raise_error(ZendeskAppsSupport::Validations::ValidationError)
    end
  end

  describe '#single_install' do
    context 'when singleInstall is a boolean in the manifest' do
      it 'returns true when singleInstall is true' do
        manifest['singleInstall'] = true
        expect(package.manifest_json['singleInstall']).to be_truthy
      end

      it 'returns false when singleInstall is false' do
        manifest['singleInstall'] = false
        expect(package.manifest_json['singleInstall']).to be_falsey
      end
    end

    context 'when singleInstall is missing from the manifest' do
      it 'returns false' do
        expect(package.manifest_json['singleInstall']).to be_falsey
      end
    end
  end

  describe '#is_no_template' do
    context 'when noTemplate is a boolean in the manifest' do
      it 'returns true when noTemplate is true' do
        manifest['noTemplate'] = true
        expect(package.is_no_template).to be_truthy
      end

      it 'returns false when noTemplate is false' do
        manifest['noTemplate'] = false
        expect(package.is_no_template).to be_falsey
      end
    end
    context 'when noTemplate is an array of locations' do
      it 'returns false' do
        manifest['noTemplate'] = ['new_ticket_sidebar', 'nav_bar']
        expect(package.is_no_template).to be_falsey
      end
    end
  end

  describe '#no_template_locations' do
    context 'when noTemplate is a boolean in the manifest' do
      it 'returns true when noTemplate is true' do
        manifest['noTemplate'] = true
        expect(package.no_template_locations).to be_truthy
      end

      it 'returns false when noTemplate is false' do
        manifest['noTemplate'] = false
        expect(package.no_template_locations).to be_falsey
      end
    end
    context 'when noTemplate is an array of locations' do
      let(:no_template_locations) { ['new_ticket_sidebar', 'nav_bar'] }
      it 'returns the array of locations' do
        manifest['noTemplate'] = no_template_locations
        expect(package.no_template_locations).to eq(no_template_locations)
      end
    end
  end

  describe '#commonjs_modules' do
    let (:modules) { package.send(:commonjs_modules) }

    context 'when there are js modules' do
      let (:source) do
        build_app_source_with_files({
          'lib/a.js'     => File.read('spec/bookmarks_app/lib/a.js'),
          'lib/foo/b.js' => File.read('spec/bookmarks_app/lib/foo/b.js')
        })
      end

      it 'returns the contents of the file at lib/a.js' do
        expect(modules["a.js"]).to eq(File.read('spec/bookmarks_app/lib/a.js'))
      end

      it 'returns the contents of the file in subfolder lib/foo/b.js' do
        expect(modules["foo/b.js"]).to eq(File.read('spec/bookmarks_app/lib/foo/b.js'))
      end
    end

    context 'when there are no js modules' do
      it { expect(modules).not_to be nil }
    end
  end

  describe "#locations" do
    it "supports strings" do
      location_object = @package.send(:locations)
      expect(location_object).to eq({"zendesk"=>{"ticket_sidebar"=>"_legacy"}})
    end

    it "supports arrays" do
      @package.manifest_json['location'] = %w[🔔 🃏]
      location_object = @package.send(:locations)
      expect(location_object).to eq({"zendesk"=>{"🃏"=>"_legacy", "🔔"=>"_legacy"}})
    end

    it "supports objects with arrays, outputs objects" do
      @package.manifest_json['location'] = { 'zendesk' => ['ticket_sidebar', 'new_ticket_sidebar'] }
      location_object = @package.send(:locations)
      expect(location_object).to eq({ 'zendesk' => { 'ticket_sidebar' => '_legacy', 'new_ticket_sidebar' => '_legacy'} })
    end

    it "supports objects with objects" do
      @package.manifest_json['location'] = { 'zopim' => {'chat_sidebar' => 'http://www.zopim.com'} }
      location_object = @package.send(:locations)
      expect(location_object).to be @package.manifest_json['location']
    end
  end


  describe '#legacy_non_iframe_app' do
    it 'should return true for an app that doesn\'t define any iframe uris' do
      legacy_uri_stub = ZendeskAppsSupport::Package::LEGACY_URI_STUB
      @package.manifest_json['location'] = { 'zopim' => { 'chat_sidebar' => legacy_uri_stub } }
      expect(@package.send(:legacy_non_iframe_app?)).to be_truthy
    end

    it 'should return false for an app that defines any iframe uris' do
      @package.manifest_json['location'] = { 'zopim' => { 'chat_sidebar' => 'http://zopim.com' } }
      expect(@package.send(:legacy_non_iframe_app?)).to be_falsey
    end
  end
end
