var http = require('http');
var jade = require('jade');
var connect = require('connect');
var fs = require('fs');
var assert = require('assert');
var url = require('url');
var ObjectID = require('mongodb').ObjectID;
var messages = require('./messages.json');
var constants = require('./constants.json');
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

  index: function(response) {

    return index_template({sprints: response.sprints, messages: messages});
  },
  sprint: function(response) {

    return sprint_template({sprint: response.sprint, stories: response.stories, calculations: response.calculations, messages: messages});
  },
  story: function(response) {

    return story_template({story: response.story, tasks: response.tasks, sprint: response.sprint, messages: messages});
  },
  task: function(response) {

    return task_template({task: response.task, story: response.story, sprint: response.sprint, messages: messages});  
  }
};

var clients = [];

var ensure = function(checkFn, exception, value) {

  if (!checkFn(value)) {

    throw exception;
  }
  return value;
};

var partial = function (fn) {

  var aps = Array.prototype.slice;
  var args = aps.call(arguments, 1);
  
  return function() {

    return fn.apply(this, args.concat(aps.call(arguments)));
  };
};

var curry2 = function (fn) {

  return function(arg2) {

    return function(arg1) {

      return fn(arg1, arg2);
    };
  };
};

var complainWithPlain = function(err) {

  this.writeHead(500, err.toString(), {"Content-Type": "text/plain"});
  this.write(err.toString());
  this.end();  
};

var complainWithJson = function(err) {

  this.writeHead(500, err.toString());
  this.end();  
};

var postAnswer = function(key, parentKey, respond, result) {

  // TODO: rubustness
  var changes = {id: result._id.toString(), rev: result._rev, key: key, value: result[key]};
  if (parentKey !== null) {

    changes.parent_id = result[parentKey].toString();
  }
  respond(changes);
  return changes;
};

var deleteAnswer = function(respond, results) {

  var removed;
  var mapToAnswer = function(result) {

    var id, parentId, object;
    object = result.deleted;
    id = object._id.toString();
    parentId = result.parent_id.toString();
    return {id: id, parent_id: parentId};
  };

  if (!_.isArray(results)) {

    removed = mapToAnswer(results);
  } else {

    removed = _.map(results, mapToAnswer);
  }

  respond(removed);
  return removed;
};

var putAnswer = function(respond, result) {

  respond(result);
  return result;
};

function respondWithHtml(response, type, result) {

  var template, html, headers;
  // TODO: robustness
  template = htmlTemplates[type];
  html = template(result);
  headers = {'Content-Type': 'text/html', 'Cache-control': 'no-store'};

  response.writeHead(200, headers);
  response.write(html);
  response.end();
}

var respondWithJson = function(response, result) {

  // TODO: robustness      
  var headers = {'Content-Type': 'application/json'};

  response.writeHead(200, headers);
  response.write(JSON.stringify(result));            
  response.end();
};

var respondOk = function(response) {

  response.writeHead(200);
  response.end();
};

var notify = function(request, result) {

  var notifications, clientIds, clients, byParentId, byRequest, byId, byProperties, originatingClient, toNotification;

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
  byParentId = buildEqual('parent_id', result.parent_id);

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
    .filter(byParentId)
    .filter(byProperties)
    .reject(originatingClient)
    .map(toNotification)
    .value();

  tischRT.notify(notifications);
};

var indexViewQuery = function() {

  return tischDB.findSprints({}, {start: 1})
  .then(function (result) {

    return {sprints: result};
  });
};

var taskViewQuery = function(id) {

  var task, story;

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
};

var storyViewQuery = function(id) {

  var story, tasks;

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
};

var sprintViewQuery = function(id) {

  var sprint, stories;

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
    endIndex = moment(sprint.start).add('days', sprint.length - 1).format('YYYY-MM-DD');
    return tischDB.getStoriesRemainingTime(storyIds, {start: startIndex, end: endIndex});
  })
  .then(function (result) {

    return {sprint: sprint, stories: stories, calculations: {remaining_time: result}}; 
  });
};

var extractHeaderField = function(field, headers) {

  var value = headers[field];
  if (value === undefined) {

    throw 'header field "' + field + '" missing in request';
  }
  return value;
};

var extractRev = _.compose(partial(ensure, _.isFinite, '"rev" header in request is malformed.'), curry2(parseInt)(10), partial(extractHeaderField, 'rev'));

var extractParentId = partial(extractHeaderField, 'parent_id');

// TODO: move ObjectID to db.
var removeTaskQuery = function(id, rev) {

  var filter = {_id: ObjectID(id), _rev: rev};
  return tischDB.removeTask(filter, true)
  .then(function (result) {

    return {deleted: result, parent_id: result.story_id};
  });
};

var addQuery = function(dbFn, data, parentKey, parentId) {

  if (parentKey) {

    data = _.clone(data);
    data[parentKey] = ObjectID(parentId);
  }

  return dbFn(data)
  .then(function(result) {

    if (parentId) {

      return {"new": result, parent_id: parentId};
    }
    else {

      return {"new": result};
    }
  });
};

var processRequest = function(request, response) {

  var query, answer, id, parentId, rev;
  var url_parts = url.parse(request.url, true);
  //var query = url_parts.query;
  var pathname = url_parts.pathname;
  var pathParts = pathname.split("/");
  var type = (pathParts.length > 1 && pathParts[1] !== "") ? unescape(pathParts[1]) : 'index';
  var method = request.method;
  id = pathParts.length > 2 ? unescape(pathParts[2]) : null;
  var html = ((request.headers.accept !== undefined) && (request.headers.accept.match(/application\/json/) !== null)) ? false : true;
  var respond = html ? partial(respondWithHtml, response, type) : partial(respondWithJson, response);

  // simple json get requests
  if ((!html) && (method == 'GET') && (_.contains(['task', 'story', 'sprint'], type))) {

    var filter = request.headers.parent_id ? {sprint_id: ObjectID(request.headers.parent_id)} : {}; 
    var sort = {};
    if (request.headers.sort_by) {

      sort[request.headers.sort_by] = 1;
    }
    
    query = (id) ? partial(tischDB.findOne, type, id) : partial(tischDB.find, type, filter, sort);
    answer = partial(respondWithJson, response);
  }
  else if ((type == 'task') && (request.method == 'GET')) {

    query = partial(taskViewQuery, id);
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
          return tischDB.updateTaskAssignment(id, request.body.value, parseInt(request.headers.rev, 10));
        });
      }
      else {

        return tischDB.updateTask(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
      }
    };

    answer = partial(postAnswer, request.body.key, 'story_id', partial(respondWithJson, response));
  } 
  else if ((type == 'task') && (request.method == 'PUT')) {

    // TODO: check client_uuid header for all non-get requests!
    parentId = extractParentId(request.headers);

    query = partial(addQuery, tischDB.insertTask, constants.templates.task, 'story_id', parentId);  
    answer = partial(putAnswer, partial(respondWithJson, response));
  } 
  else if ((type == 'task') && (request.method == 'DELETE')) {   
      
    rev = extractRev(request.headers);

    query = partial(removeTaskQuery, id, rev);
    answer = partial(deleteAnswer, partial(respondWithJson, response));
  }   
  else if ((type == 'story') && (request.method == 'GET')) {

    query = partial(storyViewQuery, id);
    answer = respond;
  } 
  else if ((type == 'story') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      if (request.body.key == 'sprint_id') {

        return tischDB.updateStoryAssignment(id, request.body.value, parseInt(request.headers.rev, 10));
      }
      else {

        return tischDB.updateStory(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);  
      }
    };

    answer = partial(postAnswer, request.body.key, 'sprint_id', partial(respondWithJson, response));
  }
  else if ((type == 'story') && (request.method == 'PUT')) {

    parentId = extractParentId(request.headers);

    query = partial(addQuery, tischDB.insertStory, constants.templates.story, 'sprint_id', parentId);
    answer = partial(putAnswer, partial(respondWithJson, response));
  } 
  else if ((type == 'story') && (request.method == 'DELETE')) {

    rev = extractRev(request.headers);

    query = function() {

      var story;
      var filter = {_id: ObjectID(id), _rev: rev};

      return tischDB.removeStory(filter, true)
      .then(function(result) {

        story = {deleted: result, parent_id: result.sprint_id};
        filter = {story_id: ObjectID(id)};

        return tischDB.findAndRemoveTasks(filter);
      })
      .then(function(result) {

        var removed = _.map(result, function(object) {

          return {deleted: object, parent_id: object.story_id};
        });
        removed.push(story);
        return removed;
      });
    };  

    answer = partial(deleteAnswer, partial(respondWithJson, response));
  }   
  else if ((type == 'sprint') && (request.method == 'GET')) {

    query = partial(sprintViewQuery, id);
    answer = respond;
  } 
  else if ((type == 'sprint') && (request.method == 'POST')) {

    assert.ok(id, 'id url part missing.');
    assert.ok(request.headers.rev, 'rev missing in request headers.');
    assert.ok(request.headers.client_uuid, 'client_uuid missing in request headers.');

    query = function() {

      if (request.body.key == 'start') {

        request.body.value = new Date(request.body.value);
      } 

      return tischDB.updateSprint(id, parseInt(request.headers.rev, 10), request.body.key, request.body.value);
    };

    answer = partial(postAnswer, request.body.key, null, partial(respondWithJson, response));
  }
  else if ((type == 'sprint') && (request.method == 'PUT')) {

    var data = _.clone(constants.templates.sprint);
    data.start = moment().millisecond(0).second(0).minute(0).hour(0).toDate();

    query = partial(addQuery, tischDB.insertSprint, data, null, 'index');
    answer = partial(putAnswer, partial(respondWithJson, response));
  }
  else if ((type == 'sprint') && (request.method == 'DELETE')) {
  
    rev = extractRev(request.headers);

    query = function() {

      var filter = {_id: ObjectID(id), _rev: rev};
      var removed = [];

      return tischDB.removeSprint(filter, true)
      .then(function(result) {

        removed.push({deleted: result, parent_id: 'index'});
        filter = {sprint_id: ObjectID(id)};

        return tischDB.findAndRemoveStories(filter);
      })
      .then(function (result) {

        removed = removed.concat(_.map(result, function (object) {

          return {deleted: object, parent_id: object.sprint_id};
        }));

        // remove all the stories' tasks 
        return Q.all(_.map(result, function(story) {

          return tischDB.findAndRemoveTasks({story_id: story._id})
          .then(function (result) {

            return _.map(result, function (object) {

              return {deleted: object, parent_id: object.story_id};
            });
          });
        }));
      })
      .then(function (result) {

        removed = removed.concat(_.flatten(result));
        return removed;
      });
    };

    answer = partial(deleteAnswer, partial(respondWithJson, response));
  }
  else if ((type == 'index') && (request.method == 'GET')) {

    query = indexViewQuery;
    answer = respond;
  }
  else if ((type == 'remaining_time_calculation') && (request.method == 'GET')) {

    assert.notEqual(true, html, 'Remaining time calculation available only as json.');

    // TODO: implement a per-sprint method (otherwise we have have to use 1 ajax call & db per story).
    query = function() {

      assert.ok(id, 'Story id is missing in the request\'s url');

      return tischDB.findSingleStory(id)
      .then(function (result) {

        return tischDB.findSingleSprint(result.sprint_id.toString());
      })
      .then(function (result) {

        startIndex = moment(result.start).format('YYYY-MM-DD');
        endIndex = moment(result.start).add('days', result.length - 1).format('YYYY-MM-DD');
        return tischDB.getStoriesRemainingTime([id], {start: startIndex, end: endIndex});
      })
      .then(function (result) {

        return (result[id] || null);
      });
    };
    answer = respond;
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
};

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
};

module.exports = app;

if (!module.parent) {

  app.start();
}
