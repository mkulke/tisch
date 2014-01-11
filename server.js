var http = require('http');
var jade = require('jade');
var connect = require('connect');
var fs = require('fs');
var assert = require('assert');
var url = require('url');
var ObjectID = require('mongodb').ObjectID;
var messages = require('./messages.json');
var Q = require('q');
var io = require('socket.io');
var moment = require('moment');
var _ = require('underscore')._;
var tischDB = require('./db.js');
var tischRT = require('./rt.js');

var cwd = process.cwd();
var options = { pretty: false, filename: 'sprint.jade' };
var sprint_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'story.jade';
var story_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'task.jade';
var task_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);
options.filename = 'index.jade';
var index_template = jade.compile(fs.readFileSync(options.filename, 'utf8'), options);

var htmlTemplates = {

  index: index_template, 
  sprint: function(response) {

    return sprint_template({sprint: response.sprint, stories: response.stories, calculations: response.calculations, messages: messages})
  },
  story: function(response) {

    return story_template({story: response.story, tasks: response.tasks, sprint: response.sprint, messages: messages});
  },
  task: function(response) {

    return task_template({task: response.task, story: response.story, sprint: response.sprint, messages: messages});  
  }
};

var clients = [];

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

      fn(arg1, arg2);
    };
  };
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

var postAnswer = function(key, respond, result) {

  // TODO: rubustness
  var changes = {id: result._id.toString(), rev: result._rev, key: key, value: result[key]};
  respond(changes);
  return changes;
};

var deleteAnswer = function(respond, result) {

  var removed;
  var mapToAnswer = function(object) {

    return {id: object._id.toString()}
  };

  if (!_.isArray(result)) {

    removed = mapToAnswer(result);
  } else {

    removed = _.map(result, mapToAnswer);
  }

  respond(removed);
  return removed;
};

var putAnswer = function(parentKey, respond, result) {

  var parentId, added;
  if (parentKey === null) {

    parentId = 'index';  
  }
  else if (!(result[parentKey] instanceof ObjectID)) {

    // TODO i18n
    throw "The " + parentKey + " property is not an Object ID";
  }
  else {

    parentId = result[parentKey].toString();
  }
  added = {id: parentId, new: result};
  respond(added);
  return added;
};

function respondWithHtml_2(response, type, result) {

  var template, html, headers;
  // TODO: robustness
  template = htmlTemplates[type]
  html = template(result);
  headers = {'Content-Type': 'text/html', 'Cache-control': 'no-store'};

  response.writeHead(200, headers);
  response.write(html);
  response.end();
}

function respondWithJson_2(response, result) {

  // TODO: robustness      
  var headers = {'Content-Type': 'application/json'};

  response.writeHead(200, headers);
  response.write(JSON.stringify(result));            
  response.end();
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

var notify = function(request, result) {

  var clientIds, clients, byGenerator, byRequest, byId, byProperties, originatingClient, toNotification;

  // remove might supply an array as result (cascading delete)
  if (!result) {

    return;
  }
  else if (_.isArray(result)) {

    _.each(result, partial(notify, request));
    return;
  }

  var buildEqual = function(key, value) {

    return function(object) {

      if (object[key] === undefined) {

        return true;
      }
      else {

        return object[key] == value;        
      }
    };
  };

  byRequest = buildEqual('method', request.method);
  byId = buildEqual('id', result.id);

  originatingClient = function(registration) {

    return registration.client.id === request.headers.sessionid;
  };

  byProperties = partial(function(key, registration) {

    return (!registration.properties) || _.contains(registration.properties, key);
  }, result.key);

  toNotification = partial(function(result, registration){

    return {client: registration.client, index: registration.index, data: result};
  }, result);

  notifications = _.chain(tischRT.registrations())
    .filter(byRequest)
    .filter(byId)
    .filter(byProperties)
    .reject(originatingClient)
    .map(toNotification)
    .value();

  tischRT.notify(notifications);
};

function processRequest(request, response) {

  var query, answer;
  var url_parts = url.parse(request.url, true);
  //var query = url_parts.query;
  var pathname = url_parts.pathname;
  var pathParts = pathname.split("/");
  var type = (pathParts.length > 1 && pathParts[1] !== "") ? unescape(pathParts[1]) : 'index';
  var id = pathParts.length > 2 ? unescape(pathParts[2]) : null;
  var html = ((request.headers.accept !== undefined) && (request.headers.accept.match(/application\/json/) !== null)) ? false : true;
  var respond = html ? partial(respondWithHtml_2, response, type) : partial(respondWithJson_2, response);

  if ((type == 'task') && (request.method == 'GET')) {

    query = function() {

      if (html) {

        var task;
        var story;

        return tischDB.findSingleTask(id)
        .then(function (result) {

          task = result;
          return tischDB.findSingleStory(task.story_id.toString());
        })
        .then(function (result) {

          story = result;
          return tischDB.findSingleSprint(story.sprint_id.toString());
        })
        .then(function (result) {

          return {task: task, story: story, sprint: result};
        });
      }
      else {

        return tischDB.findSingleTask(id);
      }
    };

    answer = respond;
  } 
  else if ((type == 'task') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    //assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    var formerStoryId;

    query = function() {

      if (request.body.key == 'story_id') {

        return tischDB.findSingleTask(id)
        .then(function (result) {

          formerStoryId = result.story_id.toString();
          debugger;
          return tischDB.updateTaskAssignment(id, request.body.value, parseInt(request.headers.rev, 10));
        });
      }
      else {

        return tischDB.updateTask(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
      }
    };

    answer = partial(postAnswer, request.body.key, partial(respondWithJson_2, response));
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

      return tischDB.insertTask(data);
    };
    
    answer = partial(putAnswer, 'story_id', partial(respondWithJson_2, response));
  } 
  else if ((type == 'task') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev header missing in request.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};
      return tischDB.removeTask(filter, true);;
    };
      
    answer = partial(deleteAnswer, partial(respondWithJson_2, response));
  }   
  else if ((type == 'story') && (request.method == 'GET')) {

    if (id) {

      query = function() {

        var story;
        
        if (html) {

          var tasks;

          return tischDB.findSingleStory(id)
          .then(function (result) {

            story = result;
            return tischDB.findTasks({story_id: story._id}, {priority: 1});
          })
          .then(function (result) {

            tasks = result;
            return tischDB.findSingleSprint(story.sprint_id.toString());  
          })
          .then(function (result) {

            return {story: story, tasks: tasks, sprint: result}; 
          });
        } else {

          return tischDB.findSingleStory(id);
        }
      };
    } else {

      assert.notEqual(true, html, 'Generic story GET available only as json.');

      query = function(result) {

        return tischDB.findStories(request.headers.parent_id ? {sprint_id: ObjectID(request.headers.parent_id)} : {}, {title: 1});
      };
    }

    answer = respond;

  } else if ((type == 'story') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      if (request.body.key == 'sprint_id') {

        return tischDB.updateStoryAssignment(id, request.body.value, parseInt(request.headers.rev, 10));
      }
      else {

        return tischDB.updateStory(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);  
      }
    };

    answer = partial(postAnswer, request.body.key, partial(respondWithJson_2, response));
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

      return tischDB.insertStory(data);
    };
    
    answer = partial(putAnswer, 'sprint_id', partial(respondWithJson_2, response));  
  } 
  else if ((type == 'story') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      var story;
      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};

      return tischDB.removeStory(filter, true)
      .then(function(result) {

        story = result;
        filter = {story_id: ObjectID(id)};

        return tischDB.findAndRemoveTasks(filter);
      })
      .then(function(result) {

        var removed = result;
        removed.push(story);
        return removed;
      });
    };  

    answer = partial(deleteAnswer, partial(respondWithJson_2, response));
  }   
  else if ((type == 'sprint') && (request.method == 'GET')) {

    if (id) {
      
      query = function() {

        if (html) {

          var sprint;
          var stories;

          return tischDB.findSingleSprint(id)
          .then(function (result) {

            sprint = result;
            return tischDB.findStories({sprint_id: sprint._id}, {priority: 1});
          })
          .then(function (result) {

            stories = result;
            storyIds = _.chain(stories).pluck('_id').invoke('toString').value();

            // TODO: remove literals
            startIndex = moment(sprint.start).format('YYYY-MM-DD');
            endIndex = moment(sprint.start).add('days', sprint.length - 1).format('YYYY-MM-DD')
            return tischDB.getStoriesRemainingTime(storyIds, {start: startIndex, end: endIndex});
          })
          .then(function (result) {

            return {sprint: sprint, stories: stories, calculations: {remaining_time: result}}; 
          });
        }
        else {

          return tischDB.findSingleSprint(id); 
        }
      };
    } else {

      assert.notEqual(true, html, 'Generic sprint GET available only as json.');

      query = function(result) {

        return tischDB.findSprints({}, {title: 1});
      };
    }

    answer = respond;
  } 
  else if ((type == 'sprint') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.')

    query = function() {

      if (request.body.key == 'start') {

        request.body.value = new Date(request.body.value);
      } 

      return tischDB.updateSprint(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
    };

    answer = partial(postAnswer, request.body.key, partial(respondWithJson_2, response));
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

      return tischDB.insertSprint(data);
    };

    answer = partial(putAnswer, null, partial(respondWithJson_2, response));
  }
  else if ((type == 'sprint') && (request.method == 'DELETE')) {
  
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      var filter = {_id: ObjectID(id), _rev: parseInt(request.headers.rev, 10)};
      var removed = [];

      return tischDB.removeSprint(filter, true)
      .then(function(result) {

        removed.push(result);
        filter = {sprint_id: ObjectID(id)};

        return tischDB.findAndRemoveStories(filter);
      })
      .then(function (result) {

        removed = removed.concat(result);

        // remove all the stories' tasks 
        return Q.all(_.map(result, function(story) {

          return tischDB.findAndRemoveTasks({story_id: story._id});
        }));
      })
      .then(function (result) {

        removed = removed.concat(_.flatten(result));
        return removed;
      });
    };

    answer = partial(deleteAnswer, partial(respondWithJson_2, response));
  }
  else if ((type == 'index') && (request.method == 'GET')) {

    query = function() {

      return tischDB.findSprints({}, {start: 1});
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

      return tischDB.findSingleStory(id)
      .then(function (result) {

        return tischDB.findSingleSprint(result.sprint_id.toString());
      })
      .then(function (result) {

        startIndex = moment(result.start).format('YYYY-MM-DD');
        endIndex = moment(result.start).add('days', result.length - 1).format('YYYY-MM-DD')
        return tischDB.getStoriesRemainingTime([id], {start: startIndex, end: endIndex});
      })
      .then(function (result) {

        return (result[id] || null);
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

  query()
  .then(answer)
  .then(partial(notify, request))
  .fail(html ? complainWithPlain.bind(response) : complainWithJson.bind(response))
  .done();
}

var app = connect()
  .use(connect.logger('dev'))
  .use(connect.favicon())
  .use(connect.static('static'))
  .use(connect.static('vendor'))
  .use(connect.static('coffee'))
  .use(connect.bodyParser())
  .use(processRequest);

app.start = function() {

  tischDB.connect()
  .then(function() {

    var server = http.createServer(app).listen(8000, function() {
    
      console.log('Server listening on port 8000');
      tischRT.listen(server);
    });
  });
}

module.exports = app;

if (!module.parent) {

  app.start();
}
