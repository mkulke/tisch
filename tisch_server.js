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

function showItem(db, response, types, parentId, template) {

  db.collection(types.parent).findOne({_id: ObjectID(parentId)}, function(err, parent) {
  
    assert.equal(null, err);
    assert.notEqual(null, parent);
    
    var selector = {};
    selector[types.parent + "_id"] = ObjectID(parentId);
    db.collection(types.child).find(selector).sort({priority: 1}).toArray(function(err, children) {

      assert.equal(null, err);

      var html = template(parent, children);
      
      db.close();
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

function updateItem(db, response, type, post_data, fields) {

  var data = {
  
    $set: {}, 
    $inc: {_rev: 1}
  }
  
  fields.forEach(function(field) {
    
    var value = post_data[field.name];   
    switch (field.type) {
    
      case "float":
        value = parseFloat(value);
        break;
      case "int":
        value = parseInt(value);
        break;
      default:
    }
    data.$set[field.name] = value;
  });

  db.collection(type).findAndModify({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, [], data, {new: true}, function(err, result) {

    assert.equal(null, err);

    db.close(); 

    if (result == null) {
    
      response.writeHead(409, messages.en.ERROR_UPDATE);
      response.end();
    } else {

      respondWithJson(result, response);
    } 
  });
}

function removeItem(db, response, id, types, post_data) {

  db.collection(types.parent).remove({_id: ObjectID(post_data._id), _rev: parseInt(post_data._rev)}, function(err, no) {

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

function respondWithJson(result, response) {

  assert.notEqual(null, result, "result is not supposed to be null here");
      
  response.writeHead(200, {'Content-Type': 'application/json'});
  response.write(JSON.stringify(result));            
  response.end();
}

function cleanUpOnMissingParent(db, response, types, data) {

  var parentId = data[types.parent + '_id']; 
    
  db.collection(types.parent).findOne({_id: parentId}, function(err, result) {

    assert.equal(null, err);

    if (result == null) {

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
    aggregation[0]['$match'][types.parent + '_id'] = data[types.parent + '_id'];
    
    db.collection(types.child).aggregate(aggregation, function(err, result) {
  
      assert.equal(null, err);
      assert(1 >= result.length, "invalid aggregation response");
    
      var priority = 0;
      if (result.length == 1) {
      
        priority = result[0]['max_priority'] + 1;
      }
      var itemId = new ObjectID();
  
      data._id = itemId;
      data._rev = 0;
      data.priority = priority;
        
      db.collection(types.child).insert(data, function(err, result) {

        // if the story is a duplicate increade prio and run again.
  
        if (err && err.code == 11000) {

          optimistic_loop();
        } else {
    
          assert.equal(1, result.length);
          var newChild = result[0];
    
          // if the item was deleted meanwhile remove the inserted child, too.        

          if (types.parent != null) {
          
            cleanUpOnMissingParent(db, response, types, data);    
          } else {
         
            db.close();    
            respondWithJson(result, response);
          }
        }
      });
    });
  }
    
  optimistic_loop();
}

function processRequest(request, response) {

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
      
          var fields = [
          
            {name: 'title', type: 'string'}, 
            {name: 'description', type: 'string'}
          ];
      
          updateItem(db, response, "sprint", request.body, fields);
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

          var fields = [
          
            {name: 'title', type: 'string'}, 
            {name: 'description', type: 'string'},
            {name: 'priority', type: 'float'}
          ];

          updateItem(db, response, "story", request.body, fields);
        }      
        else if (request.method == "PUT") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          var parent_id = request.headers["parent_id"];
          assert.notEqual(true, parent_id, 'parent sprint_id missing in header.');
        
          var data = {
      
            description: "", 
            estimated_time: 0, 
            title: 'New Story',
            sprint_id: ObjectID(parent_id)
          };
                
          addItem(db, response, {parent: 'sprint', child: 'story'}, data);
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
      
          var fields = [
          
            {name: 'summary', type: 'string'},
            {name: 'description', type: 'string'},
            {name: 'priority', type: 'float'},
          ];
          updateItem(db, response, "task", request.body, fields);
        }
        else if (request.method == "PUT") {
      
          assert.notEqual(true, html, 'html response not supported yet.');
      
          var parent_id = request.headers["parent_id"];
          assert.notEqual(true, parent_id, 'parent sprint_id missing in header.');
        
          var data = {
      
            description: "", 
            estimated_time: 0, 
            summary: 'New Task',
            story_id: ObjectID(parent_id)
          };
        
          addItem(db, response, {parent: 'story', child: 'task'}, data);
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
  });
}

var app = connect()
  .use(connect.logger("dev"))
  .use(connect.favicon())
  .use(connect.static("static"))
  .use(connect.bodyParser())
  .use(processRequest);

http.createServer(app).listen(8000);