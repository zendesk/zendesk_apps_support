(function() {

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
