var http = require('http');
var jade = require('jade');
var connect = require('connect');
var fs = require('fs');
var assert = require('assert');
var url = require('url');
var MongoClient = require('mongodb').MongoClient;
var ObjectID = require('mongodb').ObjectID;
var messages = require('./messages.json');
var Q = require('q');
var io = require('socket.io');
var moment = require('moment');
var curry = require('curry');
var _ = require('underscore')._;

var cwd = process.cwd();
var options = { pretty: false, filename: 'sprint.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'index.jade';
var index_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);

var clients = [];

var broadcastToOtherClients = curry(function(type, sourceUUID, data) {

/*  for (var key in clients) {

    if (key != sourceUUID) {

      var client = clients[key];
      console.log('emit ' + type + ' to ' + key);
      client.emit(type, data);
    }
  }*/
});

function partial(fn) {

  var aps = Array.prototype.slice;
  var args = aps.call(arguments, 1);
  
  return function() {

    return fn.apply(this, args.concat(aps.call(arguments)));
  };
}

var broadcastUpdateToOtherClients = broadcastToOtherClients('update');
var broadcastAddToOtherClients = broadcastToOtherClients('add');
var broadcastRemoveToOtherClients = broadcastToOtherClients('remove');

function broadcastToClients(sourceUUID, data) {

  for (var key in clients) {

    if (key != sourceUUID) {

      var client = clients[key];
      console.log('emit ' + data.message + ' to ' + key);
      client.emit('message', data);
    }
  }
}

function respondWithHtml(html, response) {

  assert(html);

  var headers = {'Content-Type': 'text/html', 'Cache-control': 'no-store'};

  response.writeHead(200, headers);
  response.write(html);
  response.end();
}

function respondWithJson(json, response) {

  //assert(json, 'json cannot be null or undefined.');
      
  var headers = {'Content-Type': 'application/json'};

  response.writeHead(200, headers);
  response.write(JSON.stringify(json));            
  response.end();
}

function respondOk(response) {

  response.writeHead(200);
  response.end();
}

function getRemainingTime(db, type, parentType, parentIds, range) {

  var deferred = Q.defer();

  objectIds = parentIds.map(ObjectID);

  var map = function() {  

    var remaining_time;
    var keys = Object.keys(this.remaining_time).filter(function(key) {

      return ((key >= start) && (key <= end)); // filters out 'initial' as well
    }).sort();

    if (keys.length > 0) {

      var key = keys[keys.length - 1];
      remaining_time = this.remaining_time[key];
    }
    else {

      remaining_time = this.remaining_time.initial;
    }

    emit(this.story_id, remaining_time);
  };

  var reduce = function(key, values) {

    return Array.sum(values);
  };

  query = {};
  query[parentType + '_id'] = {$in: objectIds};
  db.collection(type).mapReduce(map, reduce, {query: query, out: {inline: 1}, scope: {start: range.start, end: range.end}}, function (err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      deferred.resolve(result);
    }
  });

  return deferred.promise;
}

function getMaxPriority(db, type, parentType, parentId) {

  var deferred = Q.defer();

  var aggregation = [
    {$match: {}},
    {$group: {_id: null, max_priority: {$max: '$priority'}}}
  ];
  aggregation[0].$match[parentType + '_id'] = parentId;

  db.collection(type).aggregate(aggregation, function(err, result) {

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
}

var insert = function(db, type, parentType, data) {

  var itemId = new ObjectID();
  data._id = itemId;
  data._rev = 0;

  if (!parentType) {

    var deferred = Q.defer();

    db.collection(type).insert(data, function(err, result) {

      if (err || (result.length != 1)) {

        deferred.reject(new Error(err ? err : 'Inserting object failed.'));
      }
      else {

        deferred.resolve(result[0]);
      }
    });

    return deferred.promise;
  }

  // TODO: not exactly atomic, do we need to clean up
  // orphaned items maybe?

  var optimisticLoop = function () {

    return getMaxPriority(db, type, parentType, data[parentType + '_id'])
    .then(function(result) {

      var priority = result;
      data.priority = priority;
    })
    .then(function() {

      var deferred = Q.defer();
      db.collection(type).insert(data, function(err, result) {

        // Run again if the story is a duplicate.

        if (err && err.code == 11000) {

          return optimisticLoop();
        }
        else if (err || (result.length != 1)) {

          deferred.reject(new Error(err ? err : 'Inserting object failed.'));
        }
        else {

          deferred.resolve(result[0]);
        }
      });
      return deferred.promise;
    });
  };

  return optimisticLoop(type, parentType, data);
};

function remove(db, type, filter, failOnNoDeletion) {

  var deferred = Q.defer();  
  db.collection(type).findAndRemove(filter, function(err, result) {

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
}

function findAndRemove(db, type, filter) {

  var deferred = Q.defer();  

  var removedIds = [];

  function loop() {

    db.collection(type).findAndRemove(filter, function(err, result) {

      if (err) {

        deferred.reject(new Error(err));
      } 
      else if (result !== null) {

        removedIds.push(result._id.toString());
        loop();
      }
      else {

        deferred.resolve(removedIds);
      }
    });
  }

  loop();
  return deferred.promise;
}

var find = function(db, type, filter, sort) {

  var deferred = Q.defer();

  if (!filter) {

    filter = {};
  }
  if (!sort) {

    sort = {};
  }

  db.collection(type).find(filter).sort(sort).toArray(function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    } else {
    
      deferred.resolve(result);
    }
  });
  return deferred.promise;
};

var findOne = function(db, type, id) {

  var deferred = Q.defer();
  db.collection(type).findOne({_id: ObjectID(id)}, function(err, result) {
  
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

var findAndModify = function(db, type, id, rev, key, value) {

  var deferred = Q.defer();

  var data = {
  
    $set: {}, 
    $inc: {_rev: 1}
  };
  data.$set[key] = value;

  db.collection(type).findAndModify({_id: ObjectID(id), _rev: rev}, [], data, {new: true}, function(err, result) {

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

var updateAssignment = function(db, type, id, rev, parentType, parentId) {

  var optimisticLoop = function () {

    return getMaxPriority(db, type, parentType, ObjectID(parentId))
    .then(function (result) {

      var deferred = Q.defer();

      var data = {

        $set: {priority: result}
      };
      data.$set[parentType + '_id'] = ObjectID(parentId);

      db.collection(type).findAndModify({_id: ObjectID(id), _rev: rev}, [], data, {new: true}, function(err, result) {

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

    return findOne(db, parentType, parentId)
    .fail(function() {

        throw "The story to which the task was assigned to does not exist.";
    })
    .then(optimisticLoop);
  }
  else {

    deferred.resolve();
    return deferred.promise;
  } 
}

var complainWithPlain = function(err) {

  this.writeHead(500, err.toString(), {"Content-Type": "text/plain"});
  this.write(err.toString());
  this.end();  
};

var complainWithJson = function(err) {

  this.writeHead(500, err.toString());
  this.end();  
};

var jsonRespond = function(response, json) {

  var headers;
  headers = {'Content-Type': 'application/json'};
  response.writeHead(200, headers);
  response.write(JSON.stringify(json));            
  response.end();
};

var postAnswer = function(key, respond, result) {

  var changes, headers;
  changes = {id: result._id, rev: result._rev, key: key, value: result[key]};
  respond(changes);
  return changes;
};

function processRequest(request, response) {

  // TODO: db is open and closed on every request? oh my.

  var db = null;
  var connectToDb = function() {

    var connect = Q.nfbind(MongoClient.connect);
    return connect('mongodb://localhost:27017/test')
    .then(function(result) {

      db = result;
      return db;
    });
  };

  var query = function() {
  };

  var answer = function() {
  };

  var cleanup = function() {

    if (db) {

      db.close(); 
    }
  }; 

  var url_parts = url.parse(request.url, true);
  //var query = url_parts.query;
  var pathname = url_parts.pathname;
  var pathParts = pathname.split("/");
  var type = pathParts.length > 1 ? unescape(pathParts[1]) : null;
  var id = pathParts.length > 2 ? unescape(pathParts[2]) : null;
  var html = true;
  var accept = (typeof request.headers.accept != 'undefined') ? request.headers.accept : null;

  if (accept && (accept.indexOf("application/json") != -1)) {
  
    html = false;
  }
    
  if ((type == 'task') && (request.method == 'GET')) {

    query = function() {

      if (html) {
        var task;
        var story;

        return findOne(db, 'task', id)
        .then(function (result) {

          task = result;
          return findOne(db, 'story', task.story_id.toString());
        })
        .then(function (result) {

          story = result;
          return findOne(db, 'sprint', story.sprint_id.toString());
        })
        .then(function (result) {

          return {task: task, story: story, sprint: result};
        });
      }
      else {

        return findOne(db, 'task', id);
      }
    };

    // TODO: merge code w/ story part.
    if (html) {

      answer = function(result) {
      
        var html = task_template({task: result.task, story: result.story, sprint: result.sprint, messages: messages});
        respondWithHtml(html, response);
      };  
    }
    else {

      answer = function(result) {

        respondWithJson(result, response);
      };        
    }
  } 
  else if ((type == 'task') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    //assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    var formerStoryId;

    query = function() {

      if (request.body.key == 'story_id') {

        return findOne(db, type, id)
        .then(function (result) {

          formerStoryId = result.story_id.toString();
          return updateAssignment(db, type, id, parseInt(request.headers.rev, 10), 'story', request.body.value);
        });
      }
      else {

        return findAndModify(db, type, id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
      }
    };

    answer = partial(postAnswer, request.body.key, partial(jsonRespond, response));
  } 
  else if ((type == 'task') && (request.method == 'PUT')) {

    assert.ok(request.headers.parent_id, 'parent_id header missing in request.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      var data = {
  
        description: "", 
        initial_estimation: 1,
        remaining_time: {initial: 1},
        time_spent: {initial: 0}, 
        summary: 'New Task',
        color: 'blue',
        story_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, 'task', 'story', data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
      broadcastAddToOtherClients(request.headers.client_uuid, {parent_id: result.story_id, object: result});
    };
  } 
  else if ((type == 'task') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev header missing in request.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return remove(db, 'task', filter, true);
    };
      
    answer = function(result) {

      respondWithJson(id, response);
      broadcastRemoveToOtherClients(request.headers.client_uuid, {id: id, parent_id: result.story_id});
    };
  }   
  else if ((type == 'story') && (request.method == 'GET')) {

    if (id) {

      query = function() {

        var story;
        var tasks;

        return findOne(db, 'story', id)
        .then(function (result) {

          story = result;
          return find(db, 'task', {story_id: story._id}, {priority: 1});
        })
        .then(function (result) {

          tasks = result;
          return findOne(db, 'sprint', story.sprint_id.toString());  
        })
        .then(function (result) {

          var sprint = result;
          return {story: story, tasks: tasks, sprint: sprint}; 
        });
      };

      if (html) {

        answer = function(result) {
        
          return Q.fcall(function() {
 
            var html = story_template({story: result.story, tasks: result.tasks, sprint: result.sprint, messages: messages});
            respondWithHtml(html, response);
          });
        };  
      }
      else {

        answer = function(result) {
        
          return Q.fcall(function() {
 
            // TODO: find tasks uncecessary in this case
            respondWithJson(result.story, response);
          });
        };        
      }
    }
    else {

      assert.notEqual(true, html, 'Generic story GET available only as json.');

      query = function(result) {

        return find(db, 'story', request.headers.parent_id ? {sprint_id: ObjectID(request.headers.parent_id)} : {}, {title: 1});
      };

      answer = function(result) {

        return Q.fcall(function() {

          respondWithJson(result, response);
        });  
      };
    }
   } else if ((type == 'story') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      if (request.body.key == 'sprint_id') {

        return updateAssignment(db, type, id, parseInt(request.headers.rev, 10), 'sprint', request.body.value)
      }
      else {

        return findAndModify(db, type, id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);  
      }
    };

    answer = partial(postAnswer, request.body.key, partial(jsonRespond, response));
  }
  else if ((type == 'story') && (request.method == 'PUT')) {

    query = function() {

      assert.ok(request.headers.parent_id, 'parent_id header missing in request.');
      assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

      var data = {
      
        description: "", 
        estimation: 5,
        color: 'yellow', 
        title: 'New Story',
        sprint_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, type, 'sprint', data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
      broadcastAddToOtherClients(request.headers.client_uuid, result);
    };
  } 
  else if ((type == 'story') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return remove(db, type, filter, true)
      .then(function() {

        filter = {story_id: ObjectID(id)};

        return findAndRemove(db, 'task', filter);
      })
      .then(function(result) {

        var removedIds = result;
        removedIds.push(id);
        return removedIds;
      });
    };  

    answer = function(result) {

      // ajax response is only the requested id.
      respondWithJson(id, response);

      var data = {id: id, sprint_id: result.story_id};
      for (var i in result) {

        var data = {id: id, story_id: result.story_id};
        broadcastRemoveToOtherClients(request.headers.client_uuid, data);

        //var removedId = result[i];
        //broadcastToClients(request.headers.client_uuid, {message: 'remove', recipient: removedId, data: removedId});
      }
    };
  }   
  else if ((type == 'sprint') && (request.method == 'GET')) {

    if (id) {
      
      query = function() {

        if (html) {

          var sprint;
          var stories;

          return findOne(db, 'sprint', id)
          .then(function (result) {

            sprint = result;
            return find(db, 'story', {sprint_id: sprint._id}, {priority: 1});
          })
          .then(function (result) {

            stories = result;
            storyIds = stories.map(function(story) {

              return story._id.toString();
            });

            // TODO: remove literals
            startIndex = moment(sprint.start).format('YYYY-MM-DD');
            endIndex = moment(sprint.start).add('days', sprint.length - 1).format('YYYY-MM-DD')
            return getRemainingTime(db, 'task', 'story', storyIds, {start: startIndex, end: endIndex});
          })
          .then(function (result) {

            var remainingTime = result.reduce(function(object, element) {

              object[element._id] = element.value;
              return object;
            }, {});

            return {sprint: sprint, stories: stories, calculations: {remaining_time: remainingTime}}; 
          });
        }
        else {

          return findOne(db, 'sprint', id); 
        }
      };

      if (html) {

        answer = function(result) {

          var html = sprint_template({sprint: result.sprint, stories: result.stories, calculations: result.calculations, messages: messages});
          respondWithHtml(html, response);
        };
      }
      else {

        answer = function(result) {
         
          respondWithJson(result, response);
        };        
      }
    }
    else {

      assert.notEqual(true, html, 'Generic sprint GET available only as json.');

      query = function(result) {

        return find(db, 'sprint', {}, {title: 1});
      };

      answer = function(result) {

        respondWithJson(result, response);
      };
    }
  } 
  else if ((type == 'sprint') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      if (request.body.key == 'start') {

        request.body.value = new Date(request.body.value);
      } 

      return findAndModify(db, type, id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
    };

    answer = partial(postAnswer, request.body.key, partial(jsonRespond, response));
  }
  else if ((type == 'sprint') && (request.method == 'PUT')) {

    query = function() {

      assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

      var data = {
      
        description: 'Sprint description',
        start: moment().millisecond(0).second(0).minute(0).hour(0).toDate(),
        length: 14,
        color: 'blue', 
        title: 'New Sprint'
      };

      return insert(db, type, null, data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
      broadcastToClients(request.headers.client_uuid, {message: 'add', recipient: request.headers.parent_id, data: result});
    };
  }
  else if ((type == 'sprint') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};
      var removedIds = [];

      return remove(db, type, filter, true)
      .then(function() {

        filter = {sprint_id: ObjectID(id)};

        return findAndRemove(db, 'story', filter);
      })
      .then(function (result) {

        removedIds = result;

        function buildCalls() {

          var calls = [];
          for (var i in removedIds) {

            var storyId = ObjectID(removedIds[i]);
            filter = {story_id: storyId};

            calls.push(findAndRemove(db, 'task', filter));
          }
          return calls;
        }

        return Q.all(buildCalls());
      })
      .then(function (result) {

        for (var i in result) {

          removedIds = removedIds.concat(result[i]);
        }
        removedIds.push(id);

        return removedIds;
      });
    };

    answer = function(result) {

      // ajax response is only the requested id.
      respondWithJson(id, response);
      for (var i in result) {

        var removedId = result[i];
        broadcastToClients(request.headers.client_uuid, {message: 'remove', recipient: removedId, data: removedId});
      }
    };
  }
  else if ((!type) && (request.method == 'GET')) {

    query = function() {

      return find(db, 'sprint', null, {start: 1});
    }
    answer = function(result) {

      var html = index_template({sprints: result, messages: messages});
      respondWithHtml(html, response);
    };
  }
  else if ((type == 'remaining_time_calculation') && (request.method == 'GET')) {

    // TODO: implement a per-sprint method (otherwise we have have to use 1 ajax call & db per story).
    query = function() {

      assert.ok(id, 'Story id is missing in the request\'s url');

      return findOne(db, 'story', id)
      .then(function (result) {

        return findOne(db, 'sprint', result.sprint_id.toString());
      })
      .then(function (result) {

        startIndex = moment(result.start).format('YYYY-MM-DD');
        endIndex = moment(result.start).add('days', result.length - 1).format('YYYY-MM-DD')
        return getRemainingTime(db, 'task', 'story', [id], {start: startIndex, end: endIndex});
      })
      .then(function (result) {

        if (result.length == 1) {

          return result[0].value;    
        }
        else {

          // TODO: i18n
          throw "Error calculating remaining time for the resource.";
        }
      });
    }
    answer = function(result) {

      assert.notEqual(true, html, 'Remaining time calculation available only as json.');

      respondWithJson(result, response);
    };
  }
  else {

    // TODO

    query = function() {

      throw 'This request is not supported.';
    };
    answer = function() {};
  }

  var notify = function(result) {

    var clientIds, clients, byGenerator, byRequest, byId, byProperties, originatingClient, toNotification;

    // TODO: result is an array on cascaded deletion
    if (!result) {

      return;
    }

    var buildEqual = function(key, value) {

      return function(object) {

        return object[key] == value;
      };
    };

    byRequest = buildEqual('method', request.method);

    byId = buildEqual('object_id', result.id);

    originatingClient = function(registration) {

      return registration.client.id === request.headers.sessionid;
    };

    byProperties = partial(function(key, registration) {

      return (!registration.properties) || _.contains(registration.properties, key);
    }, result.key);

    toNotification = partial(function(result, registration){

      return {client: registration.client, index: registration.index, data: result};
    }, result);

    notifications = _.chain(socketIO.registrations())
      .filter(byRequest)
      .filter(byId)
      .filter(byProperties)
      .reject(originatingClient)
      .map(toNotification)
      .value();

    socketIO.notify(notifications);
  };

  connectToDb()
  .then(query)
  .then(answer)
  .then(notify)
  .fail(html ? complainWithPlain.bind(response) : complainWithJson.bind(response))
  .fin(cleanup)
  .done();
}

var socketIO = function() {

  //var clients = [];
  var registrations = [];
  var socket;

  return {

    listen: function(server) {

      socket = io.listen(server);

      socket.enable('browser client etag');
      socket.enable('browser client gzip'); 
      socket.enable('browser client minification');
      socket.set('log level', 1);

      socket.on('connection', function(client) {

        console.log(["client connected, id:", client.id].join(" "));
        //clients.push(client);
        client.on('register', function(data) {

          //console.log(["register: ", JSON.stringify(data)].join(" "));
          _.each(data, function(registration) {

            _.extend(registration, {client: client})
          });
          registrations = registrations.concat(data);
          //console.log(["registrations content:", JSON.stringify(registrations)].join(" "));
        });

        client.on('unregister', function(indices) {

          var unregistered;

          unregistered = function(registration) {

            return (registration.client === client) && (_.contains(indices, registration.index))
          };
          registrations = _.reject(registrations, unregistered);
        });

        client.on('disconnect', function() {
        
          var clientEntry;

          console.log(["client disconnected, id:", client.id].join(" "));

          //clients = _.without(clients, client); 
          
          clientEntry = function(registration) {

            return (registration.client === client);
          };
          registrations = _.reject(registrations, clientEntry);
          //console.log(["registrations content:", JSON.stringify(registrations)].join(" "));
        });
      });
    },
    notify: function(notifications) {

      _.each(notifications, function (notification) {

        notification.client.emit('notify', _.omit(notification, 'client'));
      });
    },
    registrations: function() {

      return registrations;
    }
  }
}()

var app = connect()
  .use(connect.logger('dev'))
  .use(connect.favicon())
  .use(connect.static('static'))
  .use(connect.static('vendor'))
  .use(connect.static('coffee'))
  .use(connect.bodyParser())
  .use(processRequest);

app.start = function() {

  var server = http.createServer(app).listen(8000, function() {
  
    console.log('Server listening on port 8000');
    socketIO.listen(server);
  });
}

module.exports = app;

if (!module.parent) {

  app.start();
}
