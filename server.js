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
var options = { pretty: false, filename: 'sprint.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);

var clients = [];

function broadcastToClients(message, sourceUUID, data) {

  var index;
  for (var i in clients) {

    var client = clients[i];
    if (client.client_uuid != sourceUUID) {

      //console.log('emit ' + message + ' to ' + client.client_uuid);
      client.socket.emit(message, data);
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

  assert(json);
      
  var headers = {'Content-Type': 'application/json'};

  response.writeHead(200, headers);
  response.write(JSON.stringify(json));            
  response.end();
}

function respondOk(response) {

  response.writeHead(200);
  response.end();
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
    
    var priority = 1;
    if (result.length == 1) {
    
      priority = Math.ceil(result[0].max_priority + 1);
    }

    deferred.resolve(priority);
  });

  return deferred.promise;
}

var insert = function(db, type, parentType, data) {

  // TODO: not exactly atomic, do we need to clean up
  // orphaned items maybe?

  var optimisticLoop = function () {

    return getMaxPriority(db, type, parentType, data[parentType + '_id'])
    .then(function(result) {

      var itemId = new ObjectID();
      var priority = result;

      data._id = itemId;
      data._rev = 0;
      data.priority = priority;
    })
    .then(function() {

      var deferred = Q.defer();
      db.collection(type).insert(data, function(err, result) {

        // Run again if the story is a duplicate.

        if (err && err.code == 11000) {

          return optimisticLoop();
        }
        else if (err) {

          deferred.reject(new Error(err));
        }
        else {

          assert.equal(1, result.length);
          var item = result[0];

          deferred.resolve(item);
        }
      });
      return deferred.promise;
    });
  };

  return optimisticLoop(type, parentType, data);
};

function remove(db, type, filter, failOnNoDeletion) {

  var deferred = Q.defer();  
  db.collection(type).remove(filter, function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    } 
    else if (failOnNoDeletion && (result <= 0)) {

      deferred.reject(new Error(messages.en.ERROR_REMOVE));
    } 
    else {
    
      deferred.resolve();
    }
  });
  return deferred.promise;  
}

function findAndRemove(db, type, filter, removedIds) {

  var deferred = Q.defer();  

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

var find = function(db, type, filter) {

  var deferred = Q.defer();  
  db.collection(type).find(filter).sort({priority: 1}).toArray(function(err, result) {

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

  this.writeHead(500, "Error", {"Content-Type": "text/plain"});
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

      var task;

      return findOne(db, 'task', id)
      .then(function (result) {

        task = result;
        return findOne(db, 'story', task.story_id.toString());
      })
      .then(function (result) {

        var story = result;
        return {task: task, story: story};
      });
    };

    // TODO: merge code w/ story part.
    if (html) {

      answer = function(result) {
      
        return Q.fcall(function() {

          var html = task_template({task: result.task, story: result.story});
          respondWithHtml(html, response);
        });
      };  
    }
    else {

      answer = function(result) {
      
        return Q.fcall(function() {

          // TODO: story find unecessary in this case. 
          respondWithJson(result.task, response);
        });
      };        
    }
  } 
  else if ((type == 'task') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      if (request.body.key == 'story_id') {

        return updateAssignment(db, type, id, parseInt(request.headers.rev, 10), 'story', request.body.value)
      }
      else {

        return findAndModify(db, type, id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);  
      }
    };

    answer = function(result) {

      return Q.fcall(function() {

        var data = {rev: result._rev, id: id, key: request.body.key, value: result[request.body.key]};
        
        respondWithJson(data, response);
        broadcastToClients('update', request.headers.client_uuid, data);
      });
    };
  } 
  else if ((type == 'task') && (request.method == 'PUT')) {

    assert.ok(request.headers.parent_id, 'parent_id header missing in request.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      var data = {
  
        description: "", 
        initial_estimation: 2,
        remaining_time: 1,
        time_spent: 1, 
        summary: 'New Task',
        color: 'blue',
        story_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, 'task', 'story', data);
    };
      
    answer = function(result) {

      var data = {parent_id: request.headers.parent_id, attributes: result};
      respondWithJson(data, response);
      broadcastToClients('add', request.headers.client_uuid, data);
    };
  } 
  else if ((type == 'task') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev header missing in request.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return remove(db, 'task', filter, true);
    };
      
    answer = function() {

      var data = [id];
      respondWithJson(data, response);
      broadcastToClients('remove', request.headers.client_uuid, data);
    };
  }   
  else if ((type == 'story') && (request.method == 'GET')) {

    if (id) {

      query = function() {

        var story;

        return findOne(db, 'story', id)
        .then(function (result) {

          story = result;
          return find(db, 'task', {story_id: story._id});
        })
        .then(function(result) {

          var tasks = result;
          return {story: story, tasks: tasks}; 
        });
      };

      if (html) {

        answer = function(result) {
        
          return Q.fcall(function() {
 
            var html = story_template({story: result.story, tasks: result.tasks});
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

        return find(db, 'story', request.headers.parent_id ? {sprint_id: ObjectID(request.headers.parent_id)} : {});
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
      broadcastToClients('update', request.headers.client_uuid, data);
    };
  } else if ((type == 'story') && (request.method == 'PUT')) {

    query = function() {

      assert.ok(request.headers.parent_id, 'parent_id header missing in request.');
      assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

      var data = {
      
        description: "", 
        estimation: 0,
        color: 'yellow', 
        title: 'New Story',
        sprint_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, type, 'sprint', data);
    };
      
    answer = function(result) {

      var data = {parent_id: request.headers.parent_id, attributes: result};
      respondWithJson(data, response);
      broadcastToClients('add', request.headers.client_uuid, data);
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

        return findAndRemove(db, 'task', filter, [id]);
      });
    };  

    answer = function(result) {

      respondWithJson(result, response);
      broadcastToClients('remove', request.headers.client_uuid, result);
    };
  }   
  else if ((type == 'sprint') && (request.method == 'GET')) {

    query = function() {

      var sprint;

      return findOne(db, 'sprint', id)
      .then(function (result) {

        sprint = result;
        return find(db, 'story', {sprint_id: sprint._id});
      })
      .then(function (result) {

        var stories = result;
        return {sprint: sprint, stories: stories}; 
      });
    };

    answer = function(result) {

      return Q.fcall(function() {

        var html = sprint_template({sprint: result.sprint, stories: result.stories});
        respondWithHtml(html, response);
      });
    };
   } else if ((type == 'sprint') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {
    
      return findAndModify(db, type, id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
    };

    answer = function(result) {

      var data = {rev: result._rev, id: id, key: request.body.key, value: result[request.body.key]};
      
      respondWithJson(data, response);
      broadcastToClients('update', request.headers.client_uuid, data);  
    };

  } else {

    // TODO

    query = function() {

      throw 'not implemented yet';
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
  .use(connect.logger("dev"))
  .use(connect.favicon())
  .use(connect.static("static"))
  .use(connect.bodyParser())
  .use(processRequest);

module.exports = app;
if (!module.parent) {

  var server = http.createServer(app).listen(8000, function() {
  
    console.log('Server listening on port 8000');  
  });

  socket = io.listen(server);

  socket.enable('browser client etag');
  socket.enable('browser client gzip'); 
  socket.enable('browser client minification');
  socket.set('log level', 1);

  socket.on('connection', function(client) {
    
    var index;

    client.on('register', function(data) {

      index = clients.push({

        socket: client,
        client_uuid: data.client_uuid,
      }) - 1;
      //console.log(data.client_uuid + ' registered. ' + clients.length + ' clients connected now.');
    });

    client.on('disconnect', function() {
    
      //var aClient = clients[index];
      clients.splice(index, 1);
      //console.log(aClient.client_uuid + ' disconnected. ' + clients.length + ' clients connected now.');
    });
  });
}
