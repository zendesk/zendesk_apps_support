require 'spec_helper'

describe ZendeskAppsSupport::Package do
  before do
    @package = ZendeskAppsSupport::Package.new('spec/app')

    lib_files_original_method = @package.method(:lib_files)
    @package.stub(:lib_files) do |*args, &block|
      lib_files_original_method.call(*args, &block).sort_by { |f| f.relative_path }
    end
  end

  describe 'files' do
    it 'should return all the files within the app folder excluding files in tmp folder' do
      @package.files.map(&:relative_path).should =~ %w(app.css app.js assets/logo-small.png assets/logo.png lib/a.js lib/a.txt lib/nested/b.js manifest.json templates/layout.hdbs translations/en.json)
    end

    it 'should error out when manifest is missing' do
     @package = ZendeskAppsSupport::Package.new('spec/app_nomanifest')
     err =  @package.validate
     err.first.class.should == ZendeskAppsSupport::Validations::ValidationError
     err.first.to_s.should == 'Could not find manifest.json'
    end
  end

  describe 'template_files' do
    it 'should return all the files in the templates folder within the app folder' do
      @package.template_files.map(&:relative_path).should == %w(templates/layout.hdbs)
    end
  end

  describe 'translation_files' do
    it 'should return all the files in the translations folder within the app folder' do
      @package.translation_files.map(&:relative_path).should == %w(translations/en.json)
    end
  end

  describe 'lib_files' do
    it 'should return all the javascript files in the lib folder within the app folder' do
      @package.lib_files.map(&:relative_path).should == %w(lib/a.js lib/nested/b.js)
    end
  end

  describe 'commonjs_modules' do
    it 'should return an object with name value pairs containing the path and code' do
      @package.commonjs_modules.should == {
        "a.js"=>"var a = {\n  name: 'This is A'\n};\n\nmodule.exports = a;\n",
        "nested/b.js"=>"var b = {\n  name: 'This is B'\n};\n\nmodule.exports = b;\n"
      }
    end
  end

  describe 'manifest_json' do
    it 'should return manifest json' do
      manifest = @package.manifest_json
      manifest[:name].should == 'ABC'
      manifest[:author][:name].should == 'John Smith'
      manifest[:author][:email].should == 'john@example.com'
      manifest[:defaultLocale].should == 'en'
      manifest[:private].should == true
      manifest[:location].should == 'ticket_sidebar'
      manifest[:frameworkVersion].should == '0.5'
    end
  end

  describe 'readified_js' do
    it 'should generate js ready for installation' do
      js = @package.readified_js(nil, 0, 'http://localhost:4567/')

      expected =<<HERE
  with( ZendeskApps.AppScope.create() ) {
    require.modules = {
        'a.js': function(exports, require, module) {
          var a = {
  name: 'This is A'
};

module.exports = a;

        },
        'nested/b.js': function(exports, require, module) {
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
      .reopenClass({ location: "ticket_sidebar" })
      .reopen({
        assetUrlPrefix: "http://localhost:4567/",
        appClassName: "app-0",
        author: {
          name: "John Smith",
          email: "john@example.com"
        },
        translations: {"app":{"name":"Buddha Machine"}},
        templates: {"layout":"<style>\\n.app-0 header .logo {\\n  background-image: url(\\"http://localhost:4567/logo-small.png\\"); }\\n.app-0 h1 {\\n  color: red; }\\n  .app-0 h1 span {\\n    color: green; }\\n</style>\\n<header>\\n  <span class=\\"logo\\"/>\\n  <h3>{{setting \\"name\\"}}</h3>\\n</header>\\n<section data-main/>\\n<footer>\\n  <a href=\\"mailto:{{author.email}}\\">\\n    {{author.name}}\\n  </a>\\n</footer>\\n</div>"},
        frameworkVersion: "0.5",
      });

    ZendeskApps["ABC"] = app;
  }

  ZendeskApps["ABC"].install({"id": 0, "app_id": 0, "settings": {"title":"ABC"}});
HERE
      js.should == expected
    end
  end
end
