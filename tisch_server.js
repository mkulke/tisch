var jade = require('jade');
var http = require('http');
var connect = require('connect');
var fs = require('fs');
var assert = require('assert');
var url = require('url');
var MongoClient = require('mongodb').MongoClient;
var ObjectID = require('mongodb').ObjectID;

var messages = require('./messages.json');

var cwd = process.cwd();
var options = { pretty: false, filename: 'sprint.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
var html_headers = {'Content-Type': 'text/html', 'Cache-control': 'no-store'};


function respond_json(err, result, response) {

  assert.equal(null, err, "query prodoced an error.");
      
  if (result == null) {
  
    // TODO: generalize error message.
  
    response.writeHead(409, 'The story could not be modified. It might have been accessed by someone else before your changes were submitted. Reloading the page will fetch the current state.');
  } else {
  
    response.writeHead(200, {'Content-Type': 'application/json'});
    response.write(JSON.stringify(result));            
  }
  response.end();
}

function respond_html(err, result, response) {

  assert.equal(null, err);
  assert.notEqual(null, result);
 
  var html = task_template({task: result});

  response.writeHead(200, html_headers);
  response.write(html);
  response.end();
}

function show_sprint(response, sprint_id) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    db.collection("sprint").findOne({_id: ObjectID(sprint_id)}, function(err, sprint) {
    
      assert.equal(null, err);
      assert.notEqual(null, sprint);
      
      db.collection("story").find({sprint_id: ObjectID(sprint_id)}).sort({priority: 1}).toArray(function(err, stories) {

        assert.equal(null, err);

        db.close();

        var html = sprint_template({sprint: sprint, stories: stories});

        response.writeHead(200, html_headers);
        response.write(html);
        response.end();
      });   
    });
  });
}

function show_story(http_response, story_id) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    db.collection("story").findOne({_id: ObjectID(story_id)}, function(err, story) {

      assert.equal(null, err);
      assert.notEqual(null, story);

      db.collection("task").find({story_id: ObjectID(story_id)}).toArray(function(err, tasks) {

        assert.equal(null, err);

        db.close();
  
        var html = story_template({story: story, tasks: tasks});
  
        http_response.writeHead(200, html_headers);
        http_response.write(html);
        http_response.end();
      });
    });
  });
}

function show_task(response, task_id) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    db.collection("task").findOne({_id: ObjectID(task_id)}, function(err, result) {

      assert.equal(null, err);
      assert.notEqual(null, result);
    
      var html = task_template({task: result});

      response.writeHead(200, html_headers);
      response.write(html);
      response.end(); 
      
      db.close();      
    });
  });
}

function update_story(response, story_id, post_data, respond) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    var data = {
    
      $set: {description: post_data.description, title: post_data.title, priority: parseFloat(post_data.priority)}, 
      $inc: {_rev: 1}
    }

    db.collection("story").findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

      respond(err, result, response); 
    }); 
  });
}

function update_sprint(response, sprint_id, post_data, respond) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    var data = {
    
      $set: {description: post_data.description, title: post_data.title}, 
      $inc: {_rev: 1}
    }

    db.collection("sprint").findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

      respond(err, result, response); 
    }); 
  });
}

function removeItem(response, id, types, post_data) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    db.collection(types.parent).remove({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, function(err, no) {

      assert.equal(null, err);
            
      if (no <= 0) {
    
        response.writeHead(409, messages.en.ERROR_STORY_REMOVE);
      } else {
  
        var selector = {};
        selector[types.parent + "_id"] = ObjectID(post_data._id);
                
        db.collection(types.child).remove(selector, function(err, no) {
          
          response.writeHead(200);
        });
      }
      response.end();  
    }); 
  });
}

function addChild(response, parent_id, types, respond) {

  function optimistic_loop(response, parent_id, respond, db) {

    // get child w/ max priority.
    
    db.collection(types.child).aggregate({$group: { _id: '$' + types.parent + '_id', max_priority: {$max: '$priority'}}}, function(err, result) {
  
      assert.equal(null, err);
      assert.equal(1, result.length);
    
      var priority = result[0]['max_priority'] + 1;
      var objectId = new ObjectID();
  
      var object = {
      
        _id: objectId, _rev: 0, 
        description: "", 
        estimated_time: 0, 
        priority: priority, 
        title: 'New Child'
      };
      object[types.parent + '_id'] = ObjectID(parent_id);
      
      db.collection(types.child).insert(object, function(err, result) {

        // if the story is a duplicate increade prio and run again.
  
        if (err && err.code == 11000) {

          optimistic_loop(response, parent_id, respond, db);
        } else {
    
          assert.equal(1, result.length);
          var newChild = result[0];
          //respond(err, result[0], response);
    
          // if the item was deleted meanwhile remove the inserted child, too.        

          db.collection(types.parent).findOne({_id: ObjectID(parent_id)}, function(err, result) {

            assert.equal(null, err);

            if (result == null) {

              db.collection(types.child).remove({_id: objectId}, function(err, no) {
    
                assert.equal(null, err);
    
                response.writeHead(409, messages.en.ERROR_STORY_ADD);
                response.end();
              });
            }
            else {
          
              respond(err, newChild, response);
            }
          });
        }
      });
    });
  }

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {
  
    assert.equal(null, err);
    assert.ok(db != null);  
    
    optimistic_loop(response, parent_id, respond, db);
  });
}

function update_task(response, task_id, post_data, respond) {

  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {

    assert.equal(null, err);
    assert.ok(db != null);

    var data = {
  
      $set: {description: post_data.description, status: post_data.status}, 
      $inc: {_rev: 1}
    }

    db.collection("task").findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

      respond(err, result, response);
    }); 
  });
}

function process_request(request, response) {

  console.log(request.method)

  var url_parts = url.parse(request.url, true);
  var query = url_parts.query;
  var pathname = url_parts.pathname
  var view = unescape(pathname.split("/")[1]);
  var item = unescape(pathname.split("/")[2]);
  var html = true;
  var accept = request.headers["accept"];
  if ((accept != null) && (accept.indexOf("application/json") != -1)) {
  
    html = false;
  }
  
  switch (view) {
  
    case "sprint":
    
      if (request.method == "GET") {
        
        assert.equal(true, html, 'json response not supported yet.');
        
        show_sprint(response, item);
      }
      else if (request.method == "POST") {
      
        assert.notEqual(true, html, 'html response not supported yet.');
      
        update_sprint(response, item, request.body, respond_json);
      }
      break;
    case "story":
    
      if (request.method == "GET") {
              
        show_story(response, item);
      }
      else if (request.method == "POST") {
              
        assert.notEqual(true, html, 'html response not supported yet.');

        update_story(response, item, request.body, respond_json);
      }      
      else if (request.method == "PUT") {
      
        assert.notEqual(true, html, 'html response not supported yet.');
      
        var parent_id = request.headers["parent_id"];
        assert.notEqual(true, parent_id, 'parent sprint_id missing in header.');
        
        addChild(response, parent_id, {parent: 'sprint', child: 'story'}, respond_json);
      }
      else if (request.method == "DELETE") {
      
        assert.notEqual(null, item, 'request is missing id part in url.');
      
        removeItem(response, item, {parent: 'story', child: 'task'}, request.body);
      }
      break;
    case "task":

      if (request.method == "GET") {
              
        show_task(response, item);
      }
      else if (request.method == "POST") {
      
        update_task(response, item, request.body, html ? respond_html : respond_json)
      }
      break;
    default:
    
      console.log("not implemented yet");
      response.writeHead(404, {"Content-Type": "text/plain"});
      response.write("not found");
      response.end();
  }
}

var app = connect()
  .use(connect.logger("dev"))
  .use(connect.favicon())
  .use(connect.static("static"))
  .use(connect.bodyParser())
  .use(process_request);

http.createServer(app).listen(8000);