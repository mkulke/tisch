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

function showItem(db, response, types, parentId, template) {

  db.collection(types.parent).findOne({_id: ObjectID(parentId)}, function(err, parent) {
  
    assert.equal(null, err);
    assert.notEqual(null, parent);
    
    var selector = {};
    selector[types.parent + "_id"] = ObjectID(parentId);
    db.collection(types.child).find(selector).sort({priority: 1}).toArray(function(err, children) {

      assert.equal(null, err);

      db.close();

      var html = template(parent, children);
      
      response.writeHead(200, html_headers);
      response.write(html);
      response.end();
    });   
  });
}

function show_task(db, response, task_id) {

  db.collection("task").findOne({_id: ObjectID(task_id)}, function(err, result) {

    assert.equal(null, err);
    assert.notEqual(null, result);
  
    var html = task_template({task: result});

    response.writeHead(200, html_headers);
    response.write(html);
    response.end(); 
    
    db.close();      
  });
}

function updateItem(db, response, type, post_data, respond) {

  var data = {
  
    $set: {description: post_data.description, title: post_data.title}, 
    $inc: {_rev: 1}
  }

  db.collection(type).findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

    db.close(); 

    respond(err, result, response); 
  });
}

function removeItem(db, response, id, types, post_data) {

  db.collection(types.parent).remove({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, function(err, no) {

    assert.equal(null, err);
          
    if (no <= 0) {
  
      db.close(); 
  
      response.writeHead(409, messages.en.ERROR_STORY_REMOVE);
    } else {

      var selector = {};
      selector[types.parent + "_id"] = ObjectID(post_data._id);
              
      db.collection(types.child).remove(selector, function(err, no) {
        
        db.close(); 
        
        response.writeHead(200);
      });
    }
    response.end(); 
  }); 
}

function addItem(db, response, parent_id, types, respond) {

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
        title: 'New Item'
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
    
                db.close();
    
                assert.equal(null, err);
    
                response.writeHead(409, messages.en.ERROR_STORY_ADD);
                response.end();
              });
            }
            else {
              
              db.close();
          
              respond(err, newChild, response);
            }
          });
        }
      });
    });
  }
    
  optimistic_loop(response, parent_id, respond, db);
}

function update_task(db, response, task_id, post_data, respond) {

  var data = {

    $set: {description: post_data.description, status: post_data.status}, 
    $inc: {_rev: 1}
  }

  db.collection("task").findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

    db.close();

    respond(err, result, response);
  }); 
}

function process_request(request, response) {

  var url_parts = url.parse(request.url, true);
  var query = url_parts.query;
  var pathname = url_parts.pathname
  var type = unescape(pathname.split("/")[1]);
  var id = unescape(pathname.split("/")[2]);
  var html = true;
  var accept = request.headers["accept"];
  if ((accept != null) && (accept.indexOf("application/json") != -1)) {
  
    html = false;
  }
  
  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {
  
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
      
          updateItem(db, response, "sprint", request.body, respond_json);
        }
        break;
      case "story":
    
        if (request.method == "GET") {
              
          showItem(db, response, {parent: 'story', child: 'task'}, id, function(parent, children) {
                
            return story_template({story: parent, tasks: children});
          });                       
        }
        else if (request.method == "POST") {
              
          assert.notEqual(true, html, 'html response not supported yet.');

          updateItem(db, response, "story", request.body, respond_json);
        }      
        else if (request.method == "PUT") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          var parent_id = request.headers["parent_id"];
          assert.notEqual(true, parent_id, 'parent sprint_id missing in header.');
        
          addItem(db, response, parent_id, {parent: 'sprint', child: 'story'}, respond_json);
        }
        else if (request.method == "DELETE") {
      
          assert.notEqual(null, id, 'request is missing id part in url.');
      
          removeItem(db, response, id, {parent: 'story', child: 'task'}, request.body);
        }
        break;
      case "task":

        if (request.method == "GET") {
              
          show_task(db, response, id);
        }
        else if (request.method == "POST") {
      
          update_task(db, response, id, request.body, html ? respond_html : respond_json)
        }
        break;
      default:
    
        console.log("not implemented yet");
        response.writeHead(404, {"Content-Type": "text/plain"});
        response.write("not found");
        response.end();
    }
  });
}

var app = connect()
  .use(connect.logger("dev"))
  .use(connect.favicon())
  .use(connect.static("static"))
  .use(connect.bodyParser())
  .use(process_request);

http.createServer(app).listen(8000);