function o() {
  var x
    , y;
  1+1

  var caller = arguments.caller;
  var callee = arguments.callee;

  bla = 1;

  if (x == null) {}

  var y = {
    test: true
  }

  var t = y['test'] === y.test;
}

module.exports = o;
