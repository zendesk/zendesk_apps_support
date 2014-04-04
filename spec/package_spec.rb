require 'spec_helper'

describe ZendeskAppsSupport::Package do
  before do
    @package = ZendeskAppsSupport::Package.new('spec/app')
  end

  describe 'files' do
    it 'should return all the files within the app folder excluding files in tmp folder' do
      @package.files.map(&:relative_path).should =~ %w(app.css app.js assets/logo-small.png assets/logo.png manifest.json templates/layout.hdbs translations/en.json)
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

  describe 'manifest_json' do
    it 'should return manifest json' do
      manifest = @package.manifest_json
      manifest[:name].should == 'ABC'
      manifest[:author][:name].should == 'John Smith'
      manifest[:author][:email].should == 'john@example.com'
      manifest[:author][:url].should == 'http://myapp.com'
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
(function() {
    with( require('apps/framework/app_scope') ) {

        var source = (function() {

  return {
    events: {
      'app.activated':'doSomething'
    },

    doSomething: function() {
    }
  };

}());
;

        ZendeskApps["ABC"] = ZendeskApps.defineApp(source)
                .reopenClass({ location: "ticket_sidebar" })
                .reopen({
                    assetUrlPrefix: "http://localhost:4567/",
                    appClassName: "app-0",
                    author: {
                        name: "John Smith",
                        email: "john@example.com",
                        url: "http://myapp.com"
                    },
                    translations: {"app":{\"name\":\"Buddha Machine\"}},
                    templates: {"layout":"<style>\\n.app-0 header .logo {\\n  background-image: url(\\"http://localhost:4567/logo-small.png\\"); }\\n.app-0 h1 {\\n  color: red; }\\n  .app-0 h1 span {\\n    color: green; }\\n</style>\\n<header>\\n  <span class=\\"logo\\"/>\\n  <h3>{{setting \\"name\\"}}</h3>\\n</header>\\n<section data-main/>\\n<footer>\\n  <a href=\\"mailto:{{author.email}}\\">\\n    {{author.name}}\\n  </a>\\n</footer>\\n</div>"},
                    frameworkVersion: "0.5"
                });

    }

    ZendeskApps["ABC"].install({"id": 0, "app_id": 0, "settings": {\"title\":\"ABC\"}});

}());

ZendeskApps.trigger && ZendeskApps.trigger('ready');
HERE
      js.should == expected
    end
  end
end
