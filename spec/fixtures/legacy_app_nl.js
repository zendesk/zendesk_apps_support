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
}
var app = ZendeskApps.defineApp(source)
  .reopenClass({"experiments":{},"location":{"support":{"ticket_sidebar":{"url":"_legacy"}}},"noTemplate":[],"singleInstall":false,"signedUrls":false})
  .reopen({
    appName: "EFG",
    appVersion: "1.0.0",
    locationIcons: {},
    assetUrlPrefix: "http://localhost:4567/2/",
    appClassName: "app-1",
    author: {
      name: "John Smith",
      email: "john@example.com"
    },
    translations: {"app":{}},
    templates: {"layout":"<style>\n.app-1 header .logo {\n  background-image: url(\"http://localhost:4567/2/logo-small.png\"); }\n.app-1 h1 {\n  color: red; }\n  .app-1 h1 span {\n    color: green; }\n</style>\n<header>\n  <span class=\"logo\"></span>\n  <h3>{{setting \"name\"}}</h3>\n</header>\n<section data-main></section>\n<footer>\n  <a href=\"mailto:{{author.email}}\">\n    {{author.name}}\n  </a>\n</footer>\n</div>"},
    frameworkVersion: "0.5"
  });

ZendeskApps["EFG"] = app;
