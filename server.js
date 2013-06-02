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

function showItem(db, response, types, parentId, template) {

  db.collection(types.parent).findOne({_id: ObjectID(parentId)}, function(err, parent) {
  
    assert.equal(null, err);
    assert.notEqual(null, parent);
    
    var selector = {};
    selector[types.parent + "_id"] = ObjectID(parentId);
    
    if (types.child) {
    
      db.collection(types.child).find(selector).sort({priority: 1}).toArray(function(err, children) {

        assert.equal(null, err);

        var html = template(parent, children);
      
        db.close();
        response.writeHead(200, html_headers);
        response.write(html);
        response.end();
      });   
    } else {
    
      var html = template(parent);
      
      db.close();
      response.writeHead(200, html_headers);
      response.write(html);
      response.end();  
    }
  });
}

function updateItem(db, response, type, post_data, fields) {

  var data = {
  
    $set: {}, 
    $inc: {_rev: 1}
  };
  
  try {
  
    fields.forEach(function(field) {
    
      var value = post_data[field.name];   
      switch (field.type) {
    
        case "float":
          value = parseFloat(value);
          if (isNaN(value)) {
            
            throw messages.en.ERROR_UPDATE_INVALID_INPUT;
          }
          break;
        case "int":
          value = parseInt(value, 10);
          if (isNaN(value)) {
            
            throw messages.en.ERROR_UPDATE_INVALID_INPUT;
          }
          break;
        default:
      }
      data.$set[field.name] = value;
    });
  } catch (e) {
  
    response.writeHead(422, e);
    response.end();
    return;
  }

  db.collection(type).findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev, 10)}, [], data, {new: true}, function(err, result) {

    assert.equal(null, err);

    db.close(); 

    if (!result) {
    
      response.writeHead(409, messages.en.ERROR_UPDATE_NOT_FOUND);
      response.end();
    } else {

      respondWithJson(result, response);
    } 
  });
}

function removeItem(db, response, id, types, post_data) {

  db.collection(types.parent).remove({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev, 10)}, function(err, no) {

    assert.equal(null, err);
          
    if (no <= 0) {
  
      db.close(); 
      response.writeHead(409, messages.en.ERROR_REMOVE);
      response.end();
    } else {

      // delete children if there are any

      if (types.child) {
    
        var selector = {};
        selector[types.parent + "_id"] = ObjectID(post_data._id);
              
        db.collection(types.child).remove(selector, function(err, no) {
        
          assert.equal(null, err);
          
          db.close();    
          response.writeHead(200);
          response.end();
        });
      } else {
      
        db.close();
        response.writeHead(200);
        response.end();        
      }
    }
  }); 
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

function cleanUpOnMissingParent(db, response, types, data) {

  var parentId = data[types.parent + '_id']; 
    
  db.collection(types.parent).findOne({_id: parentId}, function(err, result) {

    assert.equal(null, err);

    if (!result) {

      db.collection(types.child).remove({_id: itemId}, function(err, no) {

        db.close();

        assert.equal(null, err);

        response.writeHead(409, messages.en.ERROR_ADD);
        response.end();        
      });
    } else {
    
      db.close();
      respondWithJson(data, response);
    }
  });
}


function addItem(db, response, types, data) {

  function optimistic_loop() {

    // get child w/ max priority.
    
    var aggregation = [
      {$match: {}},
      {$group: {_id: null, max_priority: {$max: '$priority'}}}
    ];
    aggregation[0].$match[types.parent + '_id'] = data[types.parent + '_id'];
    
    db.collection(types.child).aggregate(aggregation, function(err, result) {
  
      assert.equal(null, err);
      assert(1 >= result.length, "invalid aggregation response");
    
      var priority = 1;
      if (result.length == 1) {
      
        priority = result[0].max_priority + 1;
      }
      var itemId = new ObjectID();
  
      data._id = itemId;
      data._rev = 0;
      data.priority = priority;
        
      db.collection(types.child).insert(data, function(err, result) {

        // if the story is a duplicate increase prio and run again.
  
        if (err && err.code == 11000) {

          optimistic_loop();
        } else {
    
          assert.equal(1, result.length);
          var newChild = result[0];
    
          // if the item was deleted meanwhile remove the inserted child, too.        

          if (!types.parent) {
            
            db.close();    
            respondWithJson(result, response);          
          } else {
            
            cleanUpOnMissingParent(db, response, types, data);    
          }
        }
      });
    });
  }
    
  optimistic_loop();
}

// refactored

var db;
var connectToDb = function() {

  var connect = Q.nfbind(MongoClient.connect);
  return connect('mongodb://localhost:27017/test')
  .then(function(dbLocal) {

    db = dbLocal;
  });
};

var insert = function(type, parentType, data) {

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
      else if (result.length < 1) {

        deferred.reject(new Error('invalid aggregation response'));
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


var find = function(type, filter) {

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

var findOne = function(type, id) {

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

var findAndModify = function(type, id, postData, fields) {

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

var query;

var answer;

var cleanup = function() {

  if (db) {

    db.close(); 
  }
}; 

function processRequest(request, response) {

  var complain = function(err) {

    response.writeHead(500, {"Content-Type": "text/plain"});
    response.write(err.toString());
    response.end();  
  };

  var url_parts = url.parse(request.url, true);
  var query = url_parts.query;
  var pathname = url_parts.pathname;
  var pathParts = pathname.split("/");
  var type = pathParts.length > 1 ? unescape(pathParts[1]) : null;
  var id = pathParts.length > 2 ? unescape(pathParts[2]) : null;
  var html = true;
  var accept = (typeof request.headers.accept != 'undefined') ? request.headers.accept : null;
  
  /*if (accept && (accept.indexOf("application/json") != -1)) {
  
    html = false;
  }*/
    
  if ((type == 'task') && (request.method == 'GET')) {

    query = function() {

      var task;

      return findOne('task', id)
      .then(function (result) {

        task = result;
        return findOne('story', task.story_id.toString());
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

      return findAndModify('task', id, request.body, fields);
    };

    answer = function(result) {

      return Q.fcall(function() {

        respondWithJson(result, response);
      });
    };
  } else if ((type == 'task') && (request.method == 'PUT')) {

    query = function() {

      if (typeof request.headers.parent_id == 'undefined') {

        throw "sprint_id missing in http header.";
      }

      var data = {
  
        description: "", 
        initial_estimation: 2,
        remaining_time: 1,
        time_spent: 1, 
        summary: 'New Task',
        story_id: ObjectID(request.headers.parent_id)
      };

      return insert('task', 'story', data);
    };
      
    answer = function(result) {

      respondWithJson(result, response);
    };
  } else if ((type == 'story') && (request.method == 'GET')) {

    query = function() {

      var story;

      return findOne('story', id)
      .then(function (result) {

        story = result;
        return find('task', {story_id: story._id});
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
   } else if ((type == 'story') && (request.method == 'POST')) {

    query = function() {
    
      var fields = [
      
        {name: 'title', type: 'string'}, 
        {name: 'description', type: 'string'},
        {name: 'priority', type: 'float'}
      ];

      return findAndModify('story', id, request.body, fields);
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
  .fail(complain)
  .fin(cleanup)
  .done();

  /*MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {
  
    assert.equal(null, err);
    assert.notEqual(null, db);
  
    switch (type) {
  
      case "sprint":
    
        if (request.method == "GET") {
        
          assert.equal(true, html, 'json response not supported yet.');
                
          showItem(db, response, {parent: 'sprint', child: 'story'}, id, function(parent, children) {
        
            return sprint_template({sprint: parent, stories: children});
          });
        }
        else if (request.method == "POST") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          var sprintFields = [
          
            {name: 'title', type: 'string'}, 
            {name: 'description', type: 'string'}
          ];
      
          updateItem(db, response, "sprint", request.body, sprintFields);
        }
        break;
      case "story":
    
        if (request.method == "GET") {
          
          if (!id) {
          
            response.writeHead(200, {'Content-Type': 'application/json'});
            response.write(JSON.stringify([
            
              {id: "id1", label: "Story 1"},
              {id: "id2", label: "Story ABCDEF"},
              {id: "id3", label: "Hui Bui"}
            ]));
            response.end();
          } else {
          
            showItem(db, response, {parent: 'story', child: 'task'}, id, function(parent, children) {
                
              return story_template({story: parent, tasks: children});
            });
          }                       
        }
        else if (request.method == "POST") {
              
          assert.notEqual(true, html, 'html response not supported yet.');

          var storyFields = [
          
            {name: 'title', type: 'string'}, 
            {name: 'description', type: 'string'},
            {name: 'priority', type: 'float'}
          ];

          updateItem(db, response, "story", request.body, storyFields);
        }      
        else if (request.method == "PUT") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          storyId = (typeof request.headers.parent_id != 'undefined') ? request.headers.parent_id : null;
          assert.notEqual(null, storyId, 'parent sprint_id missing in header.');
        
          var storyData = {
      
            description: "", 
            estimated_time: 0, 
            title: 'New Story',
            sprint_id: ObjectID(storyId)
          };
                
          addItem(db, response, {parent: 'sprint', child: 'story'}, storyData);
        }
        else if (request.method == "DELETE") {
      
          assert.notEqual(null, id, 'request is missing id part in url.');
      
          removeItem(db, response, id, {parent: 'story', child: 'task'}, request.body);
        }
        break;
      case "task":

        if (request.method == "GET") {
        
          showItem(db, response, {parent: 'task'}, id, function(parent, children) {
                
            return task_template({task: parent});
          });             
        }
        else if (request.method == "POST") {
      
          var fields = [
          
            {name: 'summary', type: 'string'},
            {name: 'description', type: 'string'},
            {name: 'priority', type: 'float'},
            {name: 'initial_estimation', type: 'float'},
            {name: 'remaining_time', type: 'float'},
            {name: 'time_spent', type: 'float'}
          ];
          updateItem(db, response, "task", request.body, fields);
        }
        else if (request.method == "PUT") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          var taskId = (typeof request.headers.parent_id != "undefined") ? request.headers.parent_id : null;
          assert.notEqual(null, taskId, 'parent sprint_id missing in header.');
        
          var taskData = {
      
            description: "", 
            initial_estimation: 2,
            remaining_time: 1,
            time_spent: 1, 
            summary: 'New Task',
            story_id: ObjectID(taskId)
          };
        
          addItem(db, response, {parent: 'story', child: 'task'}, taskData);
        }
        else if (request.method == "DELETE") {
      
          assert.notEqual(null, id, 'request is missing id part in url.');
      
          removeItem(db, response, id, {parent: 'task'}, request.body);
        }
        break;
      default:
    
        console.log("not implemented yet");
        response.writeHead(404, {"Content-Type": "text/plain"});
        response.write("not found");
        response.end();
    }
  });*/
}

var app = connect()
//  .use(connect.logger("dev"))
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
