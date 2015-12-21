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
      templates: {"layout":"<style>\n.app-0 header .logo {\n  background-image: url(\"http://localhost:4567/0/logo-small.png\"); }\n.app-0 h1 {\n  color: red; }\n  .app-0 h1 span {\n    color: green; }\n</style>\n<header>\n  <span class=\"logo\"></span>\n  <h3>{{setting \"name\"}}</h3>\n</header>\n<section data-main></section>\n<footer>\n  <a href=\"mailto:{{author.email}}\">\n    {{author.name}}\n  </a>\n</footer>\n</div>"},
      frameworkVersion: "0.5"
    });

  ZendeskApps["ABC"] = app;
}
