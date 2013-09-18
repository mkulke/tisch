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

var cwd = process.cwd();
var options = { pretty: false, filename: 'sprint_ractive.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story_ractive.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task_ractive.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'index.jade';
var index_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);

var clients = {};

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

function getRemainingTime(db, type, parentType, parentId) {

  var deferred = Q.defer();

  var aggregation = [
    {$match: {}},
    {$group: {_id: null, remaining_time: {$sum: '$remaining_time'}}}
  ];
  aggregation[0].$match[parentType + '_id'] = parentId;

  db.collection(type).aggregate(aggregation, function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    }
    else {

      var remainingTime = null;
      if (result.length == 1) {
      
        remainingTime = result[0].remaining_time;
      }

      deferred.resolve({id: parentId.toString(), key: 'remaining_time', value: remainingTime});      
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

function processRequest(request, response) {

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
      
        var html = task_template({task: result.task, story: result.story, sprint: result.sprint});
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
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

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

    answer = function(result) {

      var data = {rev: result._rev, id: id, key: request.body.key, value: result[request.body.key]};
      
      respondWithJson(data, response);      
      broadcastToClients(request.headers.client_uuid, {message: 'update', recipient: id, data: data});

      if (request.body.key == 'story_id') {

        // remove from old story view and add to new one, and trigger calculation updates.
        broadcastToClients(request.headers.client_uuid, {message: 'deassign', recipient: id, data: id});
        broadcastToClients(request.headers.client_uuid, {message: 'update_remaining_time', recipient: formerStoryId, data: formerStoryId});
        broadcastToClients(request.headers.client_uuid, {message: 'assign', recipient: result.story_id, data: result});
        broadcastToClients(request.headers.client_uuid, {message: 'update_remaining_time', recipient: result.story_id, data: result.story_id});
      }  
      else if (request.body.key == 'remaining_time') {

        broadcastToClients(request.headers.client_uuid, {message: 'update_remaining_time', recipient: result.story_id, data: result.story_id});
      }
    };
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
      broadcastToClients(request.headers.client_uuid, {message: 'add', recipient: request.headers.parent_id, data: result});
      broadcastToClients(request.headers.client_uuid, {message: 'update_remaining_time', recipient: result.story_id, data: result.story_id});
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
      broadcastToClients(request.headers.client_uuid, {message: 'remove', recipient: id, data: id});
      broadcastToClients(request.headers.client_uuid, {message: 'update_remaining_time', recipient: result.story_id, data: result.story_id});
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
 
            var html = story_template({story: result.story, tasks: result.tasks, sprint: result.sprint});
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

    answer = function(result) {

      var data = {rev: result._rev, id: id, key: request.body.key, value: result[request.body.key]};
      
      respondWithJson(data, response);
      broadcastToClients(request.headers.client_uuid, {message: 'update', recipient: id, data: data});
      
      if (request.body.key == 'sprint_id') {

      // remove from old story view and add to new one.
        broadcastToClients(request.headers.client_uuid, {message: 'deassign', recipient: id, data: id});
        broadcastToClients(request.headers.client_uuid, {message: 'assign', recipient: result.sprint_id, data: result});
      }
    };
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
      broadcastToClients(request.headers.client_uuid, {message: 'add', recipient: request.headers.parent_id, data: result});
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
      for (var i in result) {

        var removedId = result[i];
        broadcastToClients(request.headers.client_uuid, {message: 'remove', recipient: removedId, data: removedId});
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

            function buildCalls() {

              var calls = [];
              for (var i in stories) {

                calls.push(getRemainingTime(db, 'task', 'story', stories[i]._id));
              }

              return calls;
            }

            return Q.all(buildCalls());
          })
          .then(function (results) {

            var remaining_time = {};
            for (var i in results) {

              var result = results[i];
              remaining_time[result.id] = result.value;
            }

            return {sprint: sprint, stories: stories, calculations: {remaining_time: remaining_time}}; 
          });
        }
        else {

          return findOne(db, 'sprint', id); 
        }
      };

      if (html) {

        answer = function(result) {

          var html = sprint_template({sprint: result.sprint, stories: result.stories, calculations: result.calculations});
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

    answer = function(result) {

      var data = {rev: result._rev, id: id, key: request.body.key, value: result[request.body.key]};
      
      respondWithJson(data, response);
      broadcastToClients(request.headers.client_uuid, {message: 'update', recipient: id, data: data});  
    };
  }
  else if ((type == 'sprint') && (request.method == 'PUT')) {

    query = function() {

      assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

      var data = {
      
        description: 'Sprint description',
        start: new Date(),
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

      var html = index_template({sprints: result});
      respondWithHtml(html, response);
    };
  }
  else if ((type == 'remaining_time_calculation') && (request.method == 'GET')) {

    query = function() {

      assert.ok(id, 'Story id is missing in the request\'s url');

      return getRemainingTime(db, 'task', 'story', ObjectID(id));
    }
    answer = function(result) {

      assert.notEqual(true, html, 'Remaining time calculation available only as json.');

      respondWithJson(result.value, response);
    };
  }
  else {

    // TODO

    query = function() {

      throw 'This request is not supported.';
    };
    answer = function() {};
  }

  connectToDb()
  .then(query)
  .then(answer)
  .fail(html ? complainWithPlain.bind(response) : complainWithJson.bind(response))
  .fin(cleanup)
  .done();
}

var app = connect()
  .use(connect.logger('dev'))
  .use(connect.favicon())
  .use(connect.static('static'))
  .use(connect.static('coffee'))
  .use(connect.bodyParser())
  .use(processRequest);

app.start = function() {

  var server = http.createServer(app).listen(8000, function() {
  
    console.log('Server listening on port 8000');  
  });

  // TODO: (IMPORTANT!) make the socket.io calls async!!

  socket = io.listen(server);

  socket.enable('browser client etag');
  socket.enable('browser client gzip'); 
  socket.enable('browser client minification');
  socket.set('log level', 1);

  socket.on('connection', function(client) {
    
    var key;

    client.on('register', function(data) {

      key = data.client_uuid;
      clients[key] = client;
      console.log(key + ' registered. ' + Object.keys(clients).length + ' clients connected now.');
    });

    client.on('disconnect', function() {
    
      delete clients[key];
      console.log(key + ' disconnected. ' + Object.keys(clients).length + ' clients connected now.');
    });
  });
}

module.exports = app;

if (!module.parent) {

  app.start();
}
