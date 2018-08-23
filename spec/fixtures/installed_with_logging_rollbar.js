(function() {
  var self = this;
  var reporter = window.ZendeskReporter ? new window.ZendeskReporter() : {};

  // This is just defining a wrapped version of jQuery which simply makes a
  // pass through call to global window.jQuery and adds logging information
  // about the origin of the page to Datadog.
  function wrapped$() {
    reporter.increment && reporter.increment(
      'app_framework.app_scope.violated',
      1,
      ['origin:' + self.location.hostname]
    );
    return self.$.apply(null, arguments);
  }

  // Adding the wrapped version of jQeury to a clone of window object, which
  // will be used to bind the app's scope.
  var wrappedWindow = this.$.extend({}, self, { $: wrapped$ });
  wrappedWindow.window = wrappedWindow;
  wrappedWindow.top = wrappedWindow;

  // Trying to match a v1 apps self executing function here and bind it to the
  // wrappedWindow instance defined above.
  // }()); ==> }.bind(wrappedWindow)());
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

  }.bind(wrappedWindow)());
  ;
  }
  var app = ZendeskApps.defineApp(source)
    .reopenClass({"experiments":{},"location":{"support":{"ticket_sidebar":{"url":"_legacy"}}},"noTemplate":[],"singleInstall":false,"signedUrls":false})
    .reopen({
      appName: "ABC",
      appVersion: "1.0.0",
      locationIcons: {},
      assetUrlPrefix: "http://localhost:4567/0/",
      logoAssetHash: {"support":"logo-small.png"},
      appClassName: "app-0",
      author: {
        name: "John Smith",
        email: "john@example.com"
      },
      translations: {"app":{"name":"Buddha Machine","description":"Play zentunes","long_description":"Play zentunes in your Zendesk","installation_instructions":"Pull the big lever"}},
      templates: {"layout":"<style>\n.app-0 header .logo {\n  background-image: url(\"http://localhost:4567/0/logo-small.png\"); }\n.app-0 h1 {\n  color: red; }\n  .app-0 h1 span {\n    color: green; }\n</style>\n<header>\n  <span class=\"logo\"></span>\n  <h3>{{setting \"name\"}}</h3>\n</header>\n<section data-main></section>\n<footer>\n  <a href=\"mailto:{{author.email}}\">\n    {{author.name}}\n  </a>\n</footer>\n</div>"},
      frameworkVersion: "0.5"
    });

  ZendeskApps["ABC"] = app;



}());

ZendeskApps.rollbarAccessToken = "Sample Rollbar Token";

ZendeskApps.trigger && ZendeskApps.trigger('ready');
