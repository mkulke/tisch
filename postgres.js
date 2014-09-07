var pg = require('pg');
var config = require('./config/' + (process.env.NODE_ENV || 'development') + '.json');
var Q = require('q');
var _ = require('underscore')._;
var moment = require('moment');
var u = require('./utils.js');

var curry2 = u.curry2, curry3 = u.curry3, partial = u.partial;

var connectionString = config.db.postgres.uri + config.db.postgres.name;

var COLUMNS = {
	REMAINING_TIME: 'remaining_time',
	TIME_SPENT: 'time_spent',
	PRIORITY: 'priority',
	DESCRIPTION: 'description',
	COLOR: 'color',
	SUMMARY: 'summary',
	STORY_ID: 'story_id'
};

var TABLES = {
	TASKS: 'tasks'
};

var ERRORS = {
	ILLEGAL_COLUMN: new Error('Illegal column'),
	ILLEGAL_TABLE: new Error('Illegal table'),
	WRONG_RESULT: new Error('Wrong result')
};

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

		deferred.resolve(result);
		done();
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

// TODO: move the hardcoded stuff into some schema document or sth.
var _isTableLegal = function(table) {
	return _.chain(TABLES).values().contains(table).value();
};

// TODO: move the hardcoded stuff into some schema document or sth.
var _isColumnLegal = function(table, column) {
	var allowedColumns = {
		tasks: [
			COLUMNS.DESCRIPTION,
			COLUMNS.COLOR,
			COLUMNS.SUMMARY,
			COLUMNS.PRIORITY,
			COLUMNS.STORY_ID
		]
	};

	return _.has(allowedColumns, table) && _.contains(allowedColumns[table], column);
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

	var verifyTable = partial(_verifyTable, table);
	var verifyColumn = partial(_verifyColumn, table);
	var verifyFilterColumns = filter ? Q.all(_.chain(filter).keys().map(verifyColumn).value()) : Q.resolve;
	var verifySortColumns = sort ? Q.all(_.chain(sort).keys().map(verifyColumn).value()) : Q.resolve;

	var query = partial(_query, {text: [selectText, whereText, orderText].join(' '), values: whereValues});
	var process = _getRows;

	return verifyTable()
		.then(verifyFilterColumns)
		.then(verifySortColumns)
		.then(_connect)
		.spread(query)
		.then(process);
};

var _findOne = function(table, id) {
	var verifyTable = partial(_verifyTable, table);
	var query = partial(_query, {text: "SELECT * FROM " + table + " WHERE _id = $1", values: [id]});
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
	var verify = partial(_verifyColumn, table, column);

	var queryText = 'UPDATE ' + table + ' SET ' + column + '=$3, _rev=' + table + '._rev+1 ' +
		((table === TABLES.TASKS) ?
			'FROM enrich_task($1) AS enriched WHERE tasks._id=$1 AND tasks._rev=$2 RETURNING tasks.*, enriched.t_s_dates, enriched.r_t_days, enriched.r_t_dates, enriched.r_t_days' :
			'WHERE _id=$1 AND _rev=$2 RETURNING *'
		);

	var query = partial(_query, {text: queryText, values: [id, rev, value]});

	var confirm = function(result) {
		var count = result.rowCount;

		if (count !== 1) {
			throw new Error([count, 'entries have been updated'].join(' '));
		}

		return result;
	};

	var process = table === TABLES.TASKS ? _.partial(_processTaskRow, id) : _.compose(_.first, _getRows);

	return verify()
		.then(_connect)
		.spread(query)
		.then(confirm)
		.then(process);
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

	// The query gets remaining time date/days pairs.
	// When a task has no remaining time pair yet, a virtual one w/ sprint start and 1 is created.
	// When a story has no task, the story's estimation value is used.
  // TODO: make initial remaining time on task configurable.

	var text = [

		'SELECT s._id AS story_id, t._id AS task_id, COALESCE(r_t.date, $1) AS date, COALESCE(r_t.days, s.estimation) AS days',
		'FROM stories AS s',
		'LEFT OUTER JOIN tasks AS t ON (t.story_id = s._id)',
		'LEFT OUTER JOIN (',
		'	SELECT t2._id AS task_id, r_t2._id AS rt_id, COALESCE(r_t2.date, $1) AS date, COALESCE(r_t2.days, 1) AS days',
		' FROM tasks AS t2',
		' LEFT OUTER JOIN remaining_times AS r_t2 ON (t2._id = r_t2.task_id)',
		' WHERE (r_t2.date >= $1 AND r_t2.date <= $2) OR r_t2.date IS NULL',
		') AS r_t ON (t._id = r_t.task_id)',
		idClause,
		'ORDER BY s._id, t._id'
	].join(' ');

	var sum = function (result) {

		var rows = result.rows;
		var hasNoTask = _.compose(_.isNull, curry2(_.result)('task_id'));
		var partionedRows = _.partition(rows, hasNoTask);
		var rowsWithTasks = _.last(partionedRows);
		var rowsWithoutTasks = _.first(partionedRows);

		var summedUpPairs = _.map(rowsWithoutTasks, function (row) {
			return [row.story_id, [_buildPair(row)]];
		});

		_.mixin({maxDate: _.compose(_.last, curry2(_.sortBy)('date'))});

		var storyPairs = _.chain(rowsWithTasks).groupBy('story_id').pairs().value();
		summedUpPairs = summedUpPairs.concat(_.map(storyPairs, function (pair) {

			var storyId = _.first(pair);
			var taskRows = _.last(pair);
			_.each(taskRows, function (row) {

				row.date = _dateToString(row.date);
				row.days = parseFloat(row.days);
			});

			var dates = _.chain(taskRows).pluck('date').map(_dateToString).union([range.start]).sort().value();

			return [storyId, _.map(dates, function (date) {

				var isNewer = function (row) {
					return row.date > date;
				};

				var rowsByTask = _.groupBy(taskRows, 'task_id');

				var days = _.reduce(rowsByTask, function (memo, rows) {

					var maxRow = _.chain(rows).reject(isNewer).maxDate().value();
					// TODO: make configurable
					return memo + (maxRow ? maxRow.days : 1);
				}, 0);

				return [date, days];
			})];
		}));

		return _.sortBy(summedUpPairs, _.first);
	};

	var query = partial(_query, {text: text, values: [range.start, range.end].concat(storyIds || [])});
	var confirm = partial(_confirmPairs, storyIds);
	var process = sum;

	return _connect().spread(query).then(confirm).then(process);
};

var _confirmPairs = function (storyIds, result) {

		if (storyIds && _.chain(result.rows).pluck('story_id').uniq().value().length !== storyIds.length) {

			throw new Error('Could not calculate values for the specified story ids');
		}
		return result;
};

var _dateToString = function (date) {

	return moment(date).format('YYYY-MM-DD');
};

var _buildPair = function(row) {

	return [row.date ? _dateToString(row.date) : null, parseFloat(row.days)];
};

var _foldToDateDayPairs = function(result) {

	return _.reduce(result.rows, function(memo, row) {

		var matchingRow = _.find(memo, function(storyRow) {

			return _.first(storyRow) == row.story_id;
		});

		if (matchingRow) {

			_.last(matchingRow).push(_buildPair(row));
		}
		else {

			memo.push([row.story_id, [_buildPair(row)]]);
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

	var query = partial(_query, {text: text, values: [range.start, range.end].concat(storyIds || [])});
	var confirm = partial(_confirmPairs, storyIds);
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

	var query = partial(_query, {text: text, values: storyIds || []});
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

var _processTaskRow = function(id, result) {
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

var findSingleTask = function(id) {
	var table = 'tasks';
	var verifyTable = partial(_verifyTable, table);
	var text = 'SELECT * FROM enrich_task($1)';

	var query = _.partial(_query, {text: text, values: [id]});
	var process = _.partial(_processTaskRow, id);

	return verifyTable()
		.then(_connect)
		.spread(query)
		.then(process);
};

var updateIndexed = function(id, rev, column, value, index) {
	var verify = function() {
		return Q.fcall(function() {
			if (!_.contains([COLUMNS.REMAINING_TIME, COLUMNS.TIME_SPENT], column)) {
				throw new Error('querying column ' + column + ' is not allowed on table');
			}
		});
	};

	var sqlFn = (column === COLUMNS.REMAINING_TIME) ? 'upsert_rt' : 'upsert_ts';

	var query = partial(_query, {text: 'SELECT * FROM ' + sqlFn + '($1, $2, $3, $4)', values: [index, value, id, rev]});

	var confirm = function(result) {
		var count = result.rowCount;

		if (count !== 1) {
			throw new Error([count, 'entries have been updated'].join(' '));
		}

		return result;
	};

	var process = _.partial(_processTaskRow, id);

	return verify()
		.then(_connect)
		.spread(query)
		.then(confirm)
		.then(process);
};

var updateTask = function(id, rev, column, value, index) {

	var argumentsWithoutIndex;

	if (_.contains([COLUMNS.REMAINING_TIME, COLUMNS.TIME_SPENT], column)) {
		return updateIndexed.apply(this, arguments);
	} else {
		argumentsWithoutIndex = ['tasks'].concat(Array.prototype.slice.call(arguments, 0, 5));


		return _update.apply(this, argumentsWithoutIndex);
	}
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

	var verifyTable = partial(_verifyTable, table);
	var verifyColumn = partial(_verifyColumn, table);
	var verifyFilterColumns = filter ? Q.all(_.chain(filter).keys().map(verifyColumn).value()) : Q.resolve;
	var verifySortColumns = sort ? Q.all(_.chain(sort).keys().map(verifyColumn).value()) : Q.resolve;

	var query = partial(_query, {text: [selectText, whereText, groupText, orderText].join(' '), values: whereValues});

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

var _add = function(table, data) {
	var columns, values, verify, parameters, queryText, query, process, isColumnLegal;

	columns = _.keys(data);
	values = _.values(data);

	parameters = _.chain(_.range(1, values.length + 1)).invoke('toString').map(function(number) {
		return '$' + number;
	}).value();

	isColumnLegal = partial(_isColumnLegal, table);
	if (_.chain(columns).map(isColumnLegal).some(u.isFalsy).value()) {
		return Q.reject(ERRORS.ILLEGAL_COLUMN);
	}

	queryText = 'INSERT INTO ' + table + ' (' + columns.join(',') + ') VALUES (' + parameters.join(',') + ') RETURNING *';

	query = partial(_query, {text: queryText, values: values});

	process = function(result) {
		if (result.rows.length != 1) {
			throw new Error('id ' + id + ' does not exist on table ' + table);
		}

		return _.extend(result.rows[0], {remaining_time: {}, time_spent: {}});
	};

	return _connect().spread(query).then(process);
};

var _remove = function(table, id, rev) {
	var queryText, query, process;
	if (!_isTableLegal(table)) {
		return Q.reject(ERRORS.ILLEGAL_TABLE);
	}

	queryText = 'DELETE FROM ' + table + ' WHERE _id = $1 AND _rev = $2 RETURNING *';
	query = partial(_query, {text: queryText, values: [id, rev]});

	process = function(result) {
		if (result.rows.length != 1) {
			throw ERRORS.WRONG_RESULT;
		}

		return _.extend(result.rows[0], {remaining_time: {}, time_spent: {}});
	};

	return _connect().spread(query).then(process);
};

exports.init = Q.resolve;
exports.cleanup = cleanup;
exports.addTask = partial(_add, 'tasks');
exports.findSprints = partial(_find, 'sprints');
exports.findSingleSprint = partial(_findOne, 'sprints');
exports.findStories = partial(_find, 'stories');
exports.findSingleStory = partial(_findOne, 'stories');
exports.findOne = _findOne;
exports.findTasks = findTasks;
exports.find = _find;
exports.findSingleTask = findSingleTask;
exports.removeTask = partial(_remove, 'tasks');
exports.updateSprint = partial(_update, 'sprints');
exports.updateStory = partial(_update, 'stories');
exports.updateTask = updateTask;
exports.getStoriesRemainingTime = getStoriesRemainingTime;
exports.getStoriesTimeSpent = getStoriesTimeSpent;
exports.getStoriesTaskCount = getStoriesTaskCount;