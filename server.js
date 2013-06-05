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

var cwd = process.cwd();
var options = { pretty: false, filename: 'sprint.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);

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

var insert = function(db, type, parentType, data) {

  // TODO: not exactly atomic, do we need to clean up
  // orphaned items maybe?

  var optimisticLoop = function () {

    var deferred = Q.defer();

    // get item w/ max priority.

    var aggregation = [
      {$match: {}},
      {$group: {_id: null, max_priority: {$max: '$priority'}}}
    ];
    aggregation[0].$match[parentType + '_id'] = data[parentType + '_id'];

    db.collection(type).aggregate(aggregation, function(err, result) {

      if (err) {

        deferred.reject(new Error(err));
      }

      var priority = 1;
      if (result.length == 1) {
      
        priority = result[0].max_priority + 1;
      }
      var itemId = new ObjectID();

      data._id = itemId;
      data._rev = 0;
      data.priority = priority;

      deferred.resolve(data);
    });

    return deferred.promise;
  };

  var tryInsert = function() {

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
  };

  return optimisticLoop(type, parentType, data)
  .then(tryInsert);
};

function remove(db, type, filter, failOnNoDeletion) {

  var deferred = Q.defer();  
  db.collection(type).remove(filter, function(err, result) {

    if (err) {

      deferred.reject(new Error(err));
    } else if (failOnNoDeletion && (result <= 0)) {

      deferred.reject(new Error(messages.en.ERROR_REMOVE));
    } else {
    
      deferred.resolve();
    }
  });
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

var findAndModify = function(db, type, id, postData, fields) {

  var deferred = Q.defer();

  var data = {
  
    $set: {}, 
    $inc: {_rev: 1}
  };
  
  fields.forEach(function(field) {
  
    var value = postData[field.name];   
    switch (field.type) {
  
      case "float":
        value = parseFloat(value);
        if (isNaN(value)) {
          
          deferred.reject(new Error(messages.en.ERROR_UPDATE_INVALID_INPUT));
        }
        break;
      case "int":
        value = parseInt(value, 10);
        if (isNaN(value)) {
          
          deferred.reject(new Error(messages.en.ERROR_UPDATE_INVALID_INPUT));
        }
        break;
      default:
    }
    data.$set[field.name] = value;
  });

  db.collection(type).findAndModify({_id: ObjectID(id), _rev: parseInt(postData._rev, 10)}, [], data, {new: true}, function(err, result) {

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

    answer = function(result) {

      return Q.fcall(function() {

        var html = task_template({task: result.task, story: result.story});
        respondWithHtml(html, response);
      });
    };
  } else if ((type == 'task') && (request.method == 'POST')) {

    query = function() {

      var fields = [
        
        {name: 'summary', type: 'string'},
        {name: 'description', type: 'string'},
        {name: 'priority', type: 'float'},
        {name: 'initial_estimation', type: 'float'},
        {name: 'remaining_time', type: 'float'},
        {name: 'time_spent', type: 'float'}
      ];

      return findAndModify(db, 'task', id, request.body, fields);
    };

    answer = function(result) {

      return Q.fcall(function() {

        respondWithJson(result, response);
      });
    };
  } 
  else if ((type == 'task') && (request.method == 'PUT')) {

    query = function() {

      if (typeof request.headers.parent_id == 'undefined') {

        throw "parent_id missing in http header.";
      }

      var data = {
  
        description: "", 
        initial_estimation: 2,
        remaining_time: 1,
        time_spent: 1, 
        summary: 'New Task',
        story_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, 'task', 'story', data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
    };
  } 
  else if ((type == 'task') && (request.method == 'DELETE')) {
  
    assert.notEqual(true, html);
    assert.ok(request.headers.rev);

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return remove(db, 'task', filter, true);
    };
      
    answer = function() {

      respondWithJson({}, response);
    };
  }   
  else if ((type == 'story') && (request.method == 'GET')) {

    assert.equal(true, html, 'Story GET available only as html, yet.');

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

      answer = function(result) {

        return Q.fcall(function() {

          var html = story_template({story: result.story, tasks: result.tasks});
          respondWithHtml(html, response);
        });
      };
    }
    else {

      assert.notEqual(true, html, 'Generic story GET available only as json.');

      query = function(result) {

        return find(db, 'story', {});
      };

      answer = function(result) {

        var json = [];

        result.forEach(function(story) {

          json.push({id: story._id, label: story.title});
        });

        return Q.fcall(function() {

          respondWithJson(json, response);
        });  
      };
    }
   } else if ((type == 'story') && (request.method == 'POST')) {

    query = function() {
    
      var fields = [
      
        {name: 'title', type: 'string'}, 
        {name: 'description', type: 'string'},
        {name: 'priority', type: 'float'}
      ];

      return findAndModify(db, 'story', id, request.body, fields);
    };

    answer = function(result) {

      respondWithJson(result, response);
    };
  } else if ((type == 'story') && (request.method == 'PUT')) {

    query = function() {

      assert.ok(request.headers.parent_id, 'parent_id missing in http header.');

      var data = {
      
        description: "", 
        estimated_time: 0, 
        title: 'New Story',
        sprint_id: ObjectID(request.headers.parent_id)
      };

      return insert(db, 'story', 'sprint', data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
    };
  } 
  else if ((type == 'story') && (request.method == 'DELETE')) {
  
    assert.notEqual(true, html);
    assert.ok(request.headers.rev);

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return remove(db, 'story', filter, true)
      .then(function() {

        filter = {story_id: ObjectID(request.body._id)};

        return remove(db, 'task', filter, false);
      });
    };
      
    answer = function() {

      respondWithJson({}, response);
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

    query = function() {
    
      var fields = [
          
        {name: 'title', type: 'string'}, 
        {name: 'description', type: 'string'}
      ];

      return findAndModify(db, 'sprint', id, request.body, fields);
    };

    answer = function(result) {

      respondWithJson(result, response);
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

  http.createServer(app).listen(8000, function() {
  
    console.log('Server listening on port 8000');  
  });
}
