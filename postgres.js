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

			throw new Error('querying table ' + table + ' is not allowed.');
		}
	});
};

var _verifyColumn = function(table, column) {

	return Q.fcall(function() {

		allowedColumns = {

			'sprints': ['description', 'color', 'title', 'start', 'length'],
			'stories': ['description', 'color', 'title', 'estimation', 'sprint_id']
		};

		if (!_.has(allowedColumns, table) || !_.contains(allowedColumns[table], column)) {

			throw new Error('querying column ' + column + ' is not allowed on table ' + table);
		}
	});
};

var _getRows = curry2(_.result)('rows');

var _find = function(table, filter, sort) {

	var selectText = 'SELECT * FROM ' + table;

	var parameterCount = 1;

	var toWhereClause = function(value) {

		return value + " = $" + parameterCount++;
	};
	var whereClauses = filter ? _.chain(filter).keys().map(toWhereClause).value() : null;
	var whereText = filter ? 'WHERE ' + whereClauses.join(' AND ') : '';
	var whereValues = filter ? _.values(filter) : [];

	var toOrderClause = function(value) {

		return '$' + parameterCount++ + (value == 1 ? '' : ' desc');
	};
	var orderClauses = sort ? _.map(sort, toOrderClause) : null;
	var orderText = sort ? 'ORDER BY ' + orderClauses.join(', ') : '';
	var orderValues = sort ? _.keys(sort) : [];

	var verifyTable = partial(_verifyTable, table);
	var verifyFilterColumn = partial(_verifyColumn, table);
	var verifyFilterColumns = filter ? Q.all(_.chain(filter).keys().map(verifyFilterColumn).value()) : Q.resolve;

	var query = partial(_query, {text: [selectText, whereText, orderText].join(' '), values: whereValues.concat(orderValues)});
	var process = _getRows;
	return verifyTable().then(verifyFilterColumns).then(_connect).spread(query).then(process);
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

var cleanup = function() {

	return Q().then(function() {

		pg.end();
	});
}

exports.init = Q.resolve;
exports.cleanup = cleanup;
exports.findSprints = partial(_find, 'sprints');
exports.updateSprint = partial(_update, 'sprints');