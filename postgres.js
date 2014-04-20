var pg = require('pg');
var config = require('./config/' + (process.env.NODE_ENV || 'development') + '.json');
var Q = require('q');
var _ = require('underscore')._;
var u = require('./utils.js');

var connectionString = config.db.postgres.uri + config.db.postgres.name;

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

		allowedTables = ['sprints', 'stories', 'tasks'];

		if (!_.contains(allowedTables, table)) {

			throw new Error('querying table ' + table + ' is not allowed.');
		}
	});
};

var _verifyColumn = function(table, column) {

	return Q.fcall(function() {

		allowedColumns = {

			'sprints': ['description', 'color', 'title', 'start', 'length'],
			'stories': ['description', 'color', 'title', 'estimation', 'priority', 'sprint_id'],
			'tasks': ['description', 'color', 'summary', 'priority', 'story_id']
		};

		if (!_.has(allowedColumns, table) || !_.contains(allowedColumns[table], column)) {

			throw new Error('querying column ' + column + ' is not allowed on table ' + table);
		}
	});
};

var _getRows = u.curry2(_.result)('rows');

var _find = function(table, filter, sort) {

	var selectText = 'SELECT * FROM ' + table;

	var parameterCount = 1;

	var toWhereClause = function(value) {

		return value + " = $" + parameterCount++;
	};
	var whereClauses = filter ? _.chain(filter).keys().map(toWhereClause).value() : null;
	var whereText = filter ? 'WHERE ' + whereClauses.join(' AND ') : '';
	var whereValues = filter ? _.values(filter) : [];

	var toOrderClause = function(value, key) {

		return key + (value == 1 ? '' : ' desc');
	};
	var orderClauses = sort ? _.map(sort, toOrderClause) : null;
	var orderText = sort ? 'ORDER BY ' + orderClauses.join(', ') : '';

	var verifyTable = u.partial(_verifyTable, table);
	var verifyColumn = u.partial(_verifyColumn, table);
	var verifyFilterColumns = filter ? Q.all(_.chain(filter).keys().map(verifyColumn).value()) : Q.resolve;
	var verifySortColumns = sort ? Q.all(_.chain(sort).keys().map(verifyColumn).value()) : Q.resolve;

	var query = u.partial(_query, {text: [selectText, whereText, orderText].join(' '), values: whereValues});
	var process = _getRows;

	return verifyTable()
		.then(verifyFilterColumns)
		.then(verifySortColumns)
		.then(_connect)
		.spread(query)
		.then(process);
};

var _findOne = function(table, id) {

	var verifyTable = u.partial(_verifyTable, table);
	var query = u.partial(_query, {text: "SELECT * FROM " + table + " WHERE _id = $1", values: [id]});
	var process = function(result) {

		if (result.rows.length != 1) {

			throw new Error('id ' + id + ' does not exist on table ' + table);
		}
		return result.rows[0];
	};

	return verifyTable()
		.then(_connect)
		.spread(query)
		.then(process);
};

var _update = function(table, id, rev, column, value) {

	var verify = u.partial(_verifyColumn, table, column);
	var query = u.partial(_query, {text: "UPDATE " + table + " SET " + column + "=$3, _rev=_rev+1 WHERE _id=$1 AND _rev=$2 RETURNING *", values: [id, rev, value]});
	var confirm = function(result) {

		var count = result.rowCount;
		if (count !== 1) {

			throw new Error([count, 'entries have been updated'].join(' '));
		}
		return result;
	};
	var process = _.compose(_.first, _getRows);

	return verify().then(_connect).spread(query).then(confirm).then(process);
};

var getStoriesRemainingTime = function(storyIds, range) {

	return Q.resolve(['1', 2]);
};

var _confirmCalculation = function(ids, errorMessage, result) {

	if (ids && result.rowCount != ids.length) {

		throw new Error(errorMessage);
	}
	return result;
};

var _processCalculation = function(result) {

	rows = result.rows;
	return _.map(rows, function(row) {

		return [row.id.toString(), parseFloat(row.calculation)];
	});
};

var getStoriesRemainingTime = function(storyIds, range) {

	var text = "SELECT t.story_id, SUM(c.days) FROM tasks AS t INNER JOIN (SELECT task_id, days FROM (SELECT days, task_id, date, MAX(date) OVER (PARTITION BY task_id) AS max_date FROM remaining_times) AS r_t WHERE date=max_date) AS c ON (t._id=c.task_id) GROUP BY t.story_id";
};

var getStoriesTimesSpent = function(storyIds, range) {

	var n = 2;
	var idClause = (storyIds && storyIds.length > 0) ? 'AND t.story_id in (' + _.map(storyIds, function(id) {

		n += 1;
		return '$' + n;
	}) + ')': '';

	var text = ['SELECT t.story_id AS id, SUM(t_s.days) AS calculation FROM tasks AS t',
		'INNER JOIN times_spent AS t_s ON (t._id=t_s.task_id)',
		'WHERE t_s.date >= $1 AND t_s.date <= $2',
		idClause,
		'GROUP BY t.story_id',
		'ORDER BY t.story_id'].join(' ');

	var query = u.partial(_query, {text: text, values: [range.start, range.end].concat(storyIds || [])});
	var confirm = u.partial(_confirmCalculation, storyIds, 'Could not calculate spent times for the specified story ids');

	return _connect().spread(query).then(confirm).then(_processCalculation);
};

var getStoriesTaskCount = function(storyIds) {

	var n = 0;
	var idClause = (storyIds && storyIds.length) ? 'WHERE story_id in (' + _.map(storyIds, function(id) { 

		n += 1;
		return '$' + n;
	}) + ')' : '';
	var text = ['SELECT story_id AS id, COUNT(story_id) AS calculation FROM tasks',
		idClause,
		'GROUP BY story_id',
		'ORDER BY story_id'].join(' ');

	var query = u.partial(_query, {text: text, values: storyIds || []});
	var confirm = u.partial(_confirmCalculation, storyIds, 'Could not calculate task count for the specified story ids');

	return _connect().spread(query).then(confirm).then(_processCalculation);
};

var cleanup = function() {

	return Q().then(function() {

		pg.end();
	});
};

exports.init = Q.resolve;
exports.cleanup = cleanup;
exports.findSprints = u.partial(_find, 'sprints');
exports.findSingleSprint = u.partial(_findOne, 'sprints');
exports.findStories = u.partial(_find, 'stories');
exports.findSingleStory = u.partial(_findOne, 'stories');
exports.findTasks = u.partial(_find, 'tasks');
exports.findSingleTask = u.partial(_findOne, 'tasks');
exports.updateSprint = u.partial(_update, 'sprints');
exports.getStoriesRemainingTime = getStoriesRemainingTime;
exports.getStoriesTimesSpent = getStoriesTimesSpent;
exports.getStoriesTaskCount = getStoriesTaskCount;