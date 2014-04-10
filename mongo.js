var MongoClient = require('mongodb').MongoClient;
var ObjectID = require('mongodb').ObjectID;
var Q = require('q');
var messages = require('./messages.json');
var config = require('./config.json');
var _ = require('underscore')._;

var _processMapReduceRow;

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

var db = function() {

	var _db = null;
	return function(/* might be */) {

		if (_.isEmpty(arguments)) {

			if (_db === null) {

        // TODO: i18n
				throw "Database not connected.";
			}
			else {

				return _db;				
			}
		}
		else {

			_db = _.first(arguments);
		}
	};
}();

var connect = function() {

	var connect = Q.nfbind(MongoClient.connect);
	return connect(config.db.mongo.uri + config.db.mongo.name[process.env.NODE_ENV || 'development'])
	.then(function(result) {

		db(result);
		return result;
	});
};

_processMapReduceRow = function(row) {

  return [row._id.toString(), _.pairs(row.value)];  
};

var getTimeSpent = function(type, parentType, parentIds, range) {

  var mapFn, reduceFn, deferred, objectIds;
  
  deferred = Q.defer();
  objectIds = parentIds.map(ObjectID);

  // ATTN: map & reduce are functions which are eval'ed in mongodb.
  mapFn = function() {  

    var filtered = {};
    //var filtered = {initial: this.time_spent.initial};
    Object.keys(this.time_spent).filter(function(key) {

      return ((key >= start) && (key <= end)); // filters out 'initial' as well
    }).forEach(function(key) { 

      filtered[key] = this[key];  
    }, this.time_spent);

    // TODO: storyId? fixed here?
    emit(this.story_id, filtered);
  };

  reduceFn = function(id, times_spent) {

    // collect keys for all remaining_times

    var dateKeys = times_spent.reduce(function (memo, time_spent) {

      Object.keys(time_spent).forEach(function (key) {

        if (memo.indexOf(key) == -1) {

          memo.push(key);
        }
      });
      return memo;
    }, []).sort();
    //dateKeys.unshift(dateKeys.pop());

    return dateKeys.reduce(function(accumulated, key) {

      accumulated[key] = times_spent.reduce(function(memo, time_spent) {

        if (time_spent[key] !== undefined) {

          memo += time_spent[key];
        }
        return memo;
      }, 0);
      return accumulated;
    }, {});
  };

  query = {};
  query[parentType + '_id'] = {$in: objectIds};
  db().collection(type).mapReduce(mapFn, reduceFn, {query: query, out: {inline: 1}, scope: {start: range.start, end: range.end}}, function (err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      result = _padResult(result, parentIds);
      deferred.resolve(_.map(result, _processMapReduceRow));
    }
  });

  return deferred.promise;
};

var _padResult = function(result, ids) {

  resultIds = _.chain(result).pluck('_id').invoke('toString').value();
  padded = _.difference(ids, resultIds).map(function(id) {

    return {_id: ObjectID(id), value: []};
  });
  return result.concat(padded);
};

var getRemainingTime = function(type, parentType, parentIds, range) {

  var deferred = Q.defer();
  var objectIds = parentIds.map(ObjectID);

  // ATTN: map & reduce are functions which are eval'ed in mongodb.
  var map = function() {  

    var filtered = {initial: this.remaining_time.initial};
    Object.keys(this.remaining_time).filter(function(key) {

      return ((key >= start) && (key <= end)); // filters out 'initial' as well
    }).forEach(function(key) { 

      filtered[key] = this[key];  
    }, this.remaining_time);

    // TODO: storyId? fixed here?
    emit(this.story_id, filtered);
  };

  var reduce = function(id, remaining_times) {

    // collect keys for all remaining_times

    var dateKeys = remaining_times.reduce(function (memo, remaining_time) {

      Object.keys(remaining_time).forEach(function (key) {

        if (memo.indexOf(key) == -1) {

          memo.push(key);
        }
      });
      return memo;
    }, []).sort();
    dateKeys.unshift(dateKeys.pop());

    var buffer = [];
    return dateKeys.reduce(function(accumulated, key) {

      accumulated[key] = remaining_times.reduce(function(memo, remaining_time, index) {

        if (remaining_time[key] !== undefined) {

          var value = remaining_time[key];
          buffer[index] = value ;
          return memo + value;
        }
        else {

          return memo + buffer[index];
        }
      }, 0);
      return accumulated;
    }, {});
  };

  query = {};
  query[parentType + '_id'] = {$in: objectIds};
  db().collection(type).mapReduce(map, reduce, {query: query, out: {inline: 1}, scope: {start: range.start, end: range.end}}, function (err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      result = _padResult(result, parentIds);
      deferred.resolve(_.map(result, _processMapReduceRow));
    }
  });

  return deferred.promise;
};

var getChildCount = function(type, parentType, parentIds) {

  var deferred = Q.defer();
  var objectIds = _.map(parentIds, ObjectID);
  var zeroValues = _.range(parentIds.length).map(partial(_.identity, 0));
  var defaults = _.object(parentIds, zeroValues);
  var key = parentType + '_id';

  var filter = {};
  filter[key] = {"$in": objectIds};

  db().collection(type).find(filter).toArray(function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      var count = _.chain(result).countBy(function(child) {

        return child[key];
      }).defaults(defaults).pairs().value();

      deferred.resolve(count);
    }
  });

  return deferred.promise;
};

var getMaxPriority = function(type, parentType, parentId) {

  var deferred = Q.defer();

  var aggregation = [

    {$match: {}},
    {$group: {_id: null, max_priority: {$max: '$priority'}}}
  ];
  aggregation[0].$match[parentType + '_id'] = parentId;

  db().collection(type).aggregate(aggregation, function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      var priority = 1;
      if (result.length == 1) {
      
        priority = Math.ceil(result[0].max_priority + 1);
      }

      deferred.resolve(priority);
    }
  });

  return deferred.promise;
};

var insert = function(type, parentType, data) {

  var itemId = new ObjectID();
  data._id = itemId;
  data._rev = 0;

	var insertCb = function(deferred, err, result) {

    if (err || (result.length != 1)) {

      deferred.reject(new Error(err ? err : 'Inserting object failed.'));
    }
    else {

      deferred.resolve(result[0]);
    }
  };

  // TODO: not exactly atomic, do we need to clean up
  // orphaned items maybe?

  var optimisticLoop = function () {

    return getMaxPriority(type, parentType, data[parentType + '_id'])
    .then(function(result) {

      var priority = result;
      data.priority = priority;
    })
    .then(function() {

      var deferred = Q.defer();
      db().collection(type).insert(data, function(err, result) {

        // Run again if the story is a duplicate.

        if (err && err.code == 11000) {

          return optimisticLoop();
        }
        else {

          insertCb(deferred, err, result);
        }
      });
      return deferred.promise;
    });
  };

  if (parentType === null) {

    var deferred = Q.defer();

    db().collection(type).insert(data, partial(insertCb, deferred));

    return deferred.promise;
  }
  else {

    return optimisticLoop(type, parentType, data);
  }
};

var updateAssignment = function(type, parentType, id, parentId, rev) {

  var optimisticLoop = function () {

    return getMaxPriority(type, parentType, ObjectID(parentId))
    .then(function (result) {

      var deferred = Q.defer();

      var data = {

        $set: {priority: result}
      };
      data.$set[parentType + '_id'] = ObjectID(parentId);

      db().collection(type).findAndModify({_id: ObjectID(id), _rev: rev}, [], data, {new: true}, function(err, result) {

        // Run again if the story is a duplicate.

        if (err && err.code == 11000) {

          return optimisticLoop();
        }
        else if (err) {

          deferred.reject(new Error(err));
        }
        else {

          deferred.resolve(result);
        }
      });
      return deferred.promise;
    });
  };

  var deferred = Q.defer();

  if (parentId) {

    return findOne(parentType, parentId)
    .fail(function() {

      // TODO: i18n
      throw "The story to which the task was assigned to does not exist.";
    })
    .then(optimisticLoop);
  }
  else {

    deferred.resolve();
    return deferred.promise;
  } 
};

var remove = function(type, filter, failOnNoDeletion) {

  var deferred = Q.defer();  
  db().collection(type).findAndRemove(filter, function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    } 
    else if (failOnNoDeletion && (result <= 0)) {

      deferred.reject(new Error(messages.en.ERROR_REMOVE));
    } 
    else {
    
      deferred.resolve(result);
    }
  });
  return deferred.promise;
};

var findAndRemove = function(type, filter) {

  var deferred = Q.defer();  

  var removed = [];

  function loop() {

    db().collection(type).findAndRemove(filter, function(err, result) {

      if (err) {

        deferred.reject(new Error(err));
      } 
      else if (result !== null) {

        removed.push(result);
        loop();
      }
      else {

        deferred.resolve(removed);
      }
    });
  }

  loop();
  return deferred.promise;
};

var find = function(type, filter, sort) {

  var deferred = Q.defer();

	filter = typeof filter !== 'undefined' ? filter : {};
	sort = typeof sort !== 'undefined' ? sort : {};

  db().collection(type).find(filter).sort(sort).toArray(function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    } else {
    
      deferred.resolve(result);
    }
  });
  return deferred.promise;
};

var findOne = function(type, id) {

  var deferred = Q.defer();
  db().collection(type).findOne({_id: ObjectID(id)}, function(err, result) {
  
    if (err) {
    
      deferred.reject(new Error(err));
    }
    else if (!result) {

      deferred.reject(new Error("Query returned no result."));
    } else {
    
      deferred.resolve(result);
    }
  });
  return deferred.promise; 
};

var findAndModify = function(type, id, rev, key, value) {

  var deferred = Q.defer();

  var data = {
  
    $set: {}, 
    $inc: {_rev: 1}
  };
  data.$set[key] = value;

  db().collection(type).findAndModify({_id: ObjectID(id), _rev: rev}, [], data, {new: true}, function(err, result) {

    if (err) {
      
      deferred.reject(new Error(err));
    }
    else if (!result) {

      deferred.reject(new Error(messages.en.ERROR_UPDATE_NOT_FOUND));
    }
    else {

      deferred.resolve(result);
    }
  });
  return deferred.promise;
};

var close = function() {

	try {
	
		db().close();
	}
	catch (exception) {}
};

exports.connect = connect;
exports.close = close;
exports.updateTask = partial(findAndModify, 'task');
exports.updateStory = partial(findAndModify, 'story');
exports.updateSprint = partial(findAndModify, 'sprint');
exports.insertTask = partial(insert, 'task', 'story');
exports.insertStory = partial(insert, 'story', 'sprint');
exports.insertSprint = partial(insert, 'sprint', null);
exports.removeTask = partial(remove, 'task');
exports.removeStory = partial(remove, 'story');
exports.removeSprint = partial(remove, 'sprint');
exports.findOne = findOne;
exports.findSingleTask = partial(findOne, 'task');
exports.findSingleStory = partial(findOne, 'story');
exports.findSingleSprint = partial(findOne, 'sprint');
exports.find = find;
exports.findTasks = partial(find, 'task');
exports.findStories = partial(find, 'story');
exports.findSprints = partial(find, 'sprint');
exports.findAndRemoveTasks = partial(findAndRemove, 'task');
exports.findAndRemoveStories = partial(findAndRemove, 'story');
exports.updateTaskAssignment = partial(updateAssignment, 'task', 'story');
exports.updateStoryAssignment = partial(updateAssignment, 'story', 'sprint');
exports.getStoriesRemainingTime = partial(getRemainingTime, 'task', 'story');
exports.getStoriesTimeSpent = partial(getTimeSpent, 'task', 'story');
exports.getStoriesTaskCount = partial(getChildCount, 'task', 'story');

