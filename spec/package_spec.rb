require 'spec_helper'

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
                 lib/nested/b.js manifest.json templates/layout.hdbs translations/en.json)
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
      expect(@package.translation_files.map(&:relative_path)).to eq(%w(translations/en.json))
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
      js = @package.compile_js(app_id: 0, assets_dir: 'http://localhost:4567/0/')

      expected = <<HERE
with( ZendeskApps.AppScope.create() ) {
    require.modules = {
        "a.js": function(exports, require, module) {
          var a = {
  name: 'This is A'
};

module.exports = a;

        },
        "nested/b.js": function(exports, require, module) {
          var b = {
  name: 'This is B'
};

module.exports = b;

        },
      eom: undefined
    };

  var source = (function() {

  return {
    a: require('a.js'),

    events: {
      'app.activated':'doSomething'
    },

    doSomething: function() {
      console.log(a.name);
    }
  };

}());
;

  var app = ZendeskApps.defineApp(source)
    .reopenClass({"location":"ticket_sidebar","noTemplate":false,"singleInstall":false})
    .reopen({
      appName: "ABC",
      appVersion: "1.0.0",
      assetUrlPrefix: "http://localhost:4567/0/",
      appClassName: "app-0",
      author: {
        name: "John Smith",
        email: "john@example.com"
      },
      translations: {"app":{"name":"Buddha Machine"}},
      templates: {"layout":"<style>\\n.app-0 header .logo {\\n  background-image: url(\\"http://localhost:4567/0/logo-small.png\\"); }\\n.app-0 h1 {\\n  color: red; }\\n  .app-0 h1 span {\\n    color: green; }\\n</style>\\n<header>\\n  <span class=\\"logo\\"></span>\\n  <h3>{{setting \\"name\\"}}</h3>\\n</header>\\n<section data-main></section>\\n<footer>\\n  <a href=\\"mailto:{{author.email}}\\">\\n    {{author.name}}\\n  </a>\\n</footer>\\n</div>"},
      frameworkVersion: "0.5"
    });

  ZendeskApps["ABC"] = app;
}
HERE
      expect(js).to eq(expected)
    end
  end

  describe 'deep_hash_merge' do
    it 'should merge a simple hash' do
      hash_1   = {'id' => 1}
      hash_2   = {'id' => 2}
      expected = {'id' => 2}
      expect( @package.send(:deep_hash_merge, hash_1, hash_2) ).to eq(expected)
    end

    it 'should merge 2 hashes recursively' do
      hash_1   = {'id' => 1, 'nick' => { label: 'test', gender: 'yes'}}
      hash_2   = {'id' => 2}
      expected = {'id' => 2, 'nick' => { label: 'test', gender: 'yes'}}
      expect( @package.send(:deep_hash_merge, hash_1, hash_2) ).to eq(expected)

      hash_1   = {'id' => 1, 'nick' => { label: 'test', gender: 'yes'}}
      hash_2   = {'id' => 2, 'nick' => 'test'}
      expected = {'id' => 2, 'nick' => 'test'}
      expect( @package.send(:deep_hash_merge, hash_1, hash_2) ).to eq(expected)

      hash_1   = {'id' => 1, 'nick' => { label: { text: 'text', value: 'value'}}}
      hash_2   = {'id' => 2, 'nick' => { label: { text: 'different', option: 3}}}
      expected = {'id' => 2, 'nick' => { label: { text: 'different', value: 'value', option: 3}}}
      expect( @package.send(:deep_hash_merge, hash_1, hash_2) ).to eq(expected)
    end
  end
end
