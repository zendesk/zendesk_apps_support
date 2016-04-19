import { a } from 'a';

module.exports = {
  a: a,

  events: {
    'app.activated':'doSomething'
  },

  doSomething: function() {
    console.log(a.name);
    console.log(a.b());
  }
};
