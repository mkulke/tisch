var pg = require('pg');
var config = require('./config.json');
var Q = require('q');
var _ = require('underscore')._;

var connectionString = config.db.postgres.uri + config.db.postgres.name[process.env.NODE_ENV || 'development'];

// TODO: put in tischutils.js

function partial(fn) {

  var aps = Array.prototype.slice;
  var args = aps.call(arguments, 1);
  
  return function() {

    return fn.apply(this, args.concat(aps.call(arguments)));
  };
}

function curry2(fn) {

  return function(arg2) {

    return function(arg1) {

      return fn(arg1, arg2);
    };
  };
}

var _connect = function() {

	var deferred = Q.defer();

	pg.connect(connectionString, function(err, client, done) {

    if (err) {

      deferred.reject(new Error(err));
    }

    deferred.resolve([client, done]);
	});
	return deferred.promise;
};

var _query = function(query, client, done) {

	var deferred = Q.defer();

	client.query(query, function(err, result) {

		if (err) {

			deferred.reject(new Error(err));
		}

		done();
		deferred.resolve(result);
	});
	return deferred.promise;
};

var _verifyTable = function(table) {

	return Q.fcall(function() {

		allowedTables = ['sprints'];

		if (!_.contains(allowedTables, table)) {

			throw new Error('table ' + table + ' is not allowed.');
		}
	});
};

var _verifyColumn = function(table, column) {

	return Q.fcall(function() {

		allowedColumns = {

			'sprints': ['description', 'color', 'title', 'start', 'length']
		};

		if (!_.has(allowedColumns, table) || !_.contains(allowedColumns[table], column)) {

			throw new Error('column ' + column + ' is not allowed on table ' + table);
		}
	});
};

var _getRows = curry2(_.result)('rows');

var _find = function(table) {

	var verify = partial(_verifyTable, table);
	var query = partial(_query, 'SELECT * FROM ' + table);
	var process = _getRows;
	return verify().then(_connect).spread(query).then(process);
};

var _update = function(table, id, rev, column, value) {

	var verify = partial(_verifyColumn, table, column);
	var query = partial(_query, {text: "UPDATE " + table + " SET " + column + "=$3, _rev=_rev+1 WHERE _id=$1 AND _rev=$2 RETURNING *", values: [id, rev, value]});
	var confirm = function(result) {

		var count = result.rowCount;
		if (count !== 1) {

			throw new Error(count + " entries have been updated");
		}
		return result;
	};
	var process = _.compose(_.first, _getRows);

	return verify().then(_connect).spread(query).then(confirm).then(process);
};

exports.init = Q.resolve;
exports.cleaup = null;
exports.findSprints = partial(_find, 'sprints');
exports.updateSprint = partial(_update, 'sprints');