var pg = require('pg');
var config = require('./config/' + (process.env.NODE_ENV || 'development') + '.json');
var Q = require('q');
var _ = require('underscore')._;
var moment = require('moment');
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

var _confirmCalculation = function(ids, errorMessage, result) {

	if (ids && result.rowCount != ids.length) {

		throw new Error(errorMessage);
	}
	return result;
};

var _buildIdClause = function(ids, n) {

	return (ids && ids.length > 0) ? 'WHERE s._id IN (' + _.map(ids, function(id) {

		n += 1;
		return '$' + n;
	}) + ')': '';
};

var getStoriesRemainingTime = function(storyIds, range) {

	var idClause = _buildIdClause(storyIds, 2);

	// The query gets remaining time date/days pairs per story and sums days up per date & story. 
	// When a task has no remaining time pair yet, a virtual one w/ sprint start and 1 is created.
	// When a story has no task, the story's estimation value is used.
  // TODO: make initial remaining time on task configurable.
	var text = [

		"SELECT s._id AS story_id, COALESCE(r_t.date, $1) AS date, COALESCE(SUM(r_t.days), s.estimation) AS days",
		'FROM stories AS s',
		'LEFT OUTER JOIN tasks AS t ON (t.story_id = s._id)',
		'LEFT OUTER JOIN (',
		"  SELECT t2._id AS task_id, r_t2._id AS rt_id, COALESCE(r_t2.date, $1) AS date, COALESCE(r_t2.days, 1) AS days",
		'  FROM tasks AS t2',
		'  LEFT OUTER JOIN remaining_times AS r_t2 ON (t2._id = r_t2.task_id)',
		'  WHERE (r_t2.date >= $1 AND r_t2.date <= $2) OR r_t2.date IS NULL',
		') AS r_t ON (t._id = r_t.task_id)',
		idClause,
		'GROUP BY s._id, r_t.date',
		'ORDER BY s._id'
	].join(' ');

	var query = u.partial(_query, {text: text, values: [range.start, range.end].concat(storyIds || [])});
	var confirm = u.partial(_confirmPairs, storyIds);

	return _connect().spread(query).then(confirm).then(_foldToDateDayPairs);
};

var _confirmPairs = function(storyIds, result) {

		if (storyIds && _.chain(result.rows).pluck('story_id').uniq().value().length != storyIds.length) {

			throw new Error('Could not calculate values for the specified story ids');
		}
		return result;
};

var _foldToDateDayPairs = function(result) {

	var buildPair = function(row) {

		return [row.date ? moment(row.date).format('YYYY-MM-DD') : null, parseFloat(row.days)];
	};

	return _.reduce(result.rows, function(memo, row) {

		var matchingRow = _.find(memo, function(storyRow) {

			return _.first(storyRow) == row.story_id;
		});

		if (matchingRow) {

			_.last(matchingRow).push(buildPair(row));
		}
		else {

			memo.push([row.story_id, [buildPair(row)]]);
		}
		return memo;
	}, []);
};

var getStoriesTimeSpent = function(storyIds, range) {

	var idClause = _buildIdClause(storyIds, 2);

	var text = [

    "SELECT s._id AS story_id, t_s.date AS date, COALESCE(SUM(t_s.days), 0) AS days",
    'FROM stories AS s',
    'LEFT OUTER JOIN tasks AS t ON (s._id=t.story_id)',
    'LEFT OUTER JOIN times_spent AS t_s ON (t._id=t_s.task_id AND t_s.date >= $1 AND t_s.date <= $2)',
    idClause,
    'GROUP BY s._id, t_s.date',
    'ORDER BY s._id, date'
	].join(' ');

	var handleEmptyValues = function(result) {

		return _.map(result, function(storyEntry) {

			return [_.first(storyEntry), _.reduce(_.last(storyEntry), function(memo, pair) {

				if (_.first(pair) !== null) memo.push(pair); return memo;
			},
			[])];
		});
	};

	var query = u.partial(_query, {text: text, values: [range.start, range.end].concat(storyIds || [])});
	var confirm = u.partial(_confirmPairs, storyIds);
	var process = _.compose(handleEmptyValues, _foldToDateDayPairs);

	return _connect().spread(query).then(confirm).then(process);
};

var getStoriesTaskCount = function(storyIds) {

	var idClause = _buildIdClause(storyIds, 0);

	var text = [
		'SELECT s._id AS id, COUNT(t._id) AS calculation FROM stories AS s',
		'LEFT OUTER JOIN tasks AS t ON (s._id=t.story_id)',
		idClause,
		'GROUP BY s._id',
		'ORDER BY s._id'
	].join(' ');

	var query = u.partial(_query, {text: text, values: storyIds || []});
	var confirm = function(result) {

		if (storyIds && result.rowCount != storyIds.length) {

			throw new Error('Could not calculate task count for the specified story ids');
		}
		return result;
	};
	var process = function(result) {

		rows = result.rows;
		return _.map(rows, function(row) {

			return [row.id.toString(), parseFloat(row.calculation)];
		});
	};

	return _connect().spread(query).then(confirm).then(process);
};

var cleanup = function() {

	return Q().then(function() {

		pg.end();
	});
};

var findSingleTask = function(id) {

	var table = 'tasks';
	var verifyTable = u.partial(_verifyTable, table);
	var text = [
		'SELECT t.*, ARRAY_AGG(r_t.date) AS r_t_dates, ARRAY_AGG(r_t.days) AS r_t_days, ARRAY_AGG(t_s.date) AS t_s_dates, ARRAY_AGG(t_s.days) AS t_s_days FROM tasks AS t ',
		'LEFT OUTER JOIN remaining_times as r_t ON (r_t.task_id=t._id)',
		'LEFT OUTER JOIN times_spent AS t_s ON (t_s.task_id=t._id)',
		'WHERE t._id=$1 GROUP BY t._id'
	].join(' ');

	var query = u.partial(_query, {text: text, values: [id]});
	var process = function(result) {

		var row, task, remaining_time, time_spent;

		var buildObject = function(dates, days) {

			return _.object(_.chain(dates).compact().map(function(date) {

				return moment(date);
			}).invoke('format', 'YYYY-MM-DD').value(), days);
		};

		if (result.rows.length != 1) {

			throw new Error('id ' + id + ' does not exist on table ' + table);
		}
		row = result.rows[0];

		remaining_time = buildObject(row.r_t_dates, row.r_t_days);
		time_spent = buildObject(row.t_s_dates, row.t_s_days);
		task = _.omit(row, ['r_t_dates', 'r_t_days', 't_s_dates', 't_s_days']);
		task.remaining_time = remaining_time;
		task.time_spent = time_spent;
		return task;
	};

	return verifyTable()
		.then(_connect)
		.spread(query)
		.then(process);
};

var findTasks = function(filter, sort) {

	var table = 'tasks';
	var selectText = [
		'SELECT t.*, ARRAY_AGG(r_t.date) AS r_t_dates, ARRAY_AGG(r_t.days) AS r_t_days, ARRAY_AGG(t_s.date) AS t_s_dates, ARRAY_AGG(t_s.days) AS t_s_days FROM tasks AS t ',
		'LEFT OUTER JOIN remaining_times as r_t ON (r_t.task_id=t._id)',
		'LEFT OUTER JOIN times_spent AS t_s ON (t_s.task_id=t._id)'
	].join(' ');

	var parameterCount = 1;

	var toWhereClause = function(value) {

		return 't.' + value + ' = $' + parameterCount++;
	};
	var whereClauses = filter ? _.chain(filter).keys().map(toWhereClause).value() : null;
	var whereText = filter ? 'WHERE ' + whereClauses.join(' AND ') : '';
	var whereValues = filter ? _.values(filter) : [];

	var toOrderClause = function(value, key) {

		return 't.' + key + (value == 1 ? '' : ' desc');
	};
	var orderClauses = sort ? _.map(sort, toOrderClause) : null;
	var orderText = sort ? 'ORDER BY ' + orderClauses.join(', ') : '';

	var groupText = 'GROUP BY t._id';

	var verifyTable = u.partial(_verifyTable, table);
	var verifyColumn = u.partial(_verifyColumn, table);
	var verifyFilterColumns = filter ? Q.all(_.chain(filter).keys().map(verifyColumn).value()) : Q.resolve;
	var verifySortColumns = sort ? Q.all(_.chain(sort).keys().map(verifyColumn).value()) : Q.resolve;

	var query = u.partial(_query, {text: [selectText, whereText, groupText, orderText].join(' '), values: whereValues});

	var process = function(result) {

		var rows;
		var buildObject = function(dates, days) {

			return _.object(_.chain(dates).compact().map(function(date) {

				return moment(date);
			}).invoke('format', 'YYYY-MM-DD').value(), days);
		};

		rows = result.rows;
		return _.map(rows, function(row) {

			var task, remaining_time, time_spent;

			remaining_time = buildObject(row.r_t_dates, row.r_t_days);
			time_spent = buildObject(row.t_s_dates, row.t_s_days);
			task = _.omit(row, ['r_t_dates', 'r_t_days', 't_s_dates', 't_s_days']);
			task.remaining_time = remaining_time;
			task.time_spent = time_spent;
			return task;
		});
	};

	return verifyTable()
		.then(_connect)
		.spread(query)
		.then(process);
};

exports.init = Q.resolve;
exports.cleanup = cleanup;
exports.findSprints = u.partial(_find, 'sprints');
exports.findSingleSprint = u.partial(_findOne, 'sprints');
exports.findStories = u.partial(_find, 'stories');
exports.findSingleStory = u.partial(_findOne, 'stories');
exports.findTasks = findTasks;
exports.findSingleTask = findSingleTask;
exports.updateSprint = u.partial(_update, 'sprints');
exports.getStoriesRemainingTime = getStoriesRemainingTime;
exports.getStoriesTimeSpent = getStoriesTimeSpent;
exports.getStoriesTaskCount = getStoriesTaskCount;