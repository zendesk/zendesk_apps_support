require 'spec_helper'

describe ZendeskAppsSupport::Package do
  before do
    @package = ZendeskAppsSupport::Package.new('spec/app')
  end

  describe 'files' do
    it 'should return all the files within the app folder excluding files in tmp folder' do
      @package.files.map(&:relative_path).should =~ %w(app.css app.js assets/logo-small.png assets/logo.png lib/a.js manifest.json templates/layout.hdbs translations/en.json)
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
var require = (function() {
  var modules = {}, cache = {};

  var require = function(name, root) {
    var path = expand(root, name), indexPath = expand(path, './index'), module, fn;
    module   = cache[path] || cache[indexPath];
    if (module) {
      return module;
    } else if (fn = modules[path] || modules[path = indexPath]) {
      module = {id: path, exports: {}};
      cache[path] = module.exports;
      fn(module.exports, function(name) {
        return require(name, dirname(path));
      }, module);
      return cache[path] = module.exports;
    } else {
      throw 'module ' + name + ' not found';
    }
  };

  var expand = function(root, name) {
    var results = [], parts, part;
    // If path is relative
    if (/^\\.\\.?(\\/|$)/.test(name)) {
      parts = [root, name].join('/').split('/');
    } else {
      parts = name.split('/');
    }
    for (var i = 0, length = parts.length; i < length; i++) {
      part = parts[i];
      if (part == '..') {
        results.pop();
      } else if (part != '.' && part != '') {
        results.push(part);
      }
    }
    return results.join('/');
  };

  var dirname = function(path) {
    return path.split('/').slice(0, -1).join('/');
  };

  modules = {
    'lib/a.js': function(require, module) {
var a = {
  name: 'This is A'
};

module.exports = a;

    },
    eom: undefined
  };

  return require;
})();


  return {
    a: require('lib/a.js'),

    events: {
      'app.activated':'doSomething'
    },

    doSomething: function() {
      console.log(a.name);
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
                        email: "john@example.com"
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
