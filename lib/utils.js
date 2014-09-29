var _ = require('underscore')._;

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

var curry3 = function (fn) {
  return function(arg3) {

    return function(arg2) {

      return function(arg1) {

        return fn(arg1, arg2, arg3);
      };
    };
  };
};

var equals = function(a, b) {
  return a === b;
};

var isFalsy = function(a) {
  return a == false; // jshint ignore:line
};

var respondWithError = function(res, error) {
  return res.status(500).send(error.message);
};

var respondWithResult = function(res, result) {
  return res.json(result);
};

var addSelfLink = function(req, result) {
  result.links = [{
    rel: 'self',
    href: req.protocol + '://' + req.get('host') + req.originalUrl
  }];
  return result;
};

exports.isFalsy = isFalsy;
exports.partial = partial;
exports.curry2 = curry2;
exports.curry3 = curry3;
exports.equals = equals;
exports.respondWithError = respondWithError;
exports.respondWithResult = respondWithResult;
exports.addSelfLink = addSelfLink;
