var partial = function (fn) {

  var aps = Array.prototype.slice;
  var args = aps.call(arguments, 1);
  
  return function() {

    return fn.apply(this, args.concat(aps.call(arguments)));
  };
};

var curry2 = function (fn) {

  return function(arg2) {

    return function(arg1) {

      return fn(arg1, arg2);
    };
  };
};

var equals = function(a, b) {

  return a === b;
};

exports.partial = partial;
exports.curry2 = curry2;
exports.equals = equals;