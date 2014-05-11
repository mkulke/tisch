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
var colors = require('colors');
var _ = require('underscore')._;
var config = require('./config/' + (process.env.NODE_ENV || 'development') + '.json');
var tischDB = require('./' + (config.db.backend || 'mongo' ) + '.js');
var tischRT = require('./rt.js');
var u = require('./utils.js');

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

    _.each(result, u.partial(notify, request));
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

  byProperties = u.partial(function(key, registration) {

    return (!registration.properties) || _.contains(registration.properties, key);
  }, result.key);

  toNotification = u.partial(function(result, registration){

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

  return tischDB.findSprints(null, {start: 1})
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

  var sprint, stories, remaining_times, times_spent, range;

  return tischDB.findSingleSprint(id)
  .then(function (result) {

    sprint = result;
    return tischDB.findStories({sprint_id: sprint._id}, {priority: 1});
  })
  .then(function (result) {

    stories = result;
    storyIds = _.chain(stories).pluck('_id').invoke('toString').value();
    
    // TODO: remove literals
    range = {

      start: moment(sprint.start).format('YYYY-MM-DD'),
      end: moment(sprint.start).add('days', sprint.length - 1).format('YYYY-MM-DD')
    };

    return tischDB.getStoriesRemainingTime(storyIds, range);
  })
  .then(function (result) {

    remaining_times = result;
    return tischDB.getStoriesTimeSpent(storyIds, range);
  }).then(function (result) {

    times_spent = result;
    return tischDB.getStoriesTaskCount(storyIds);
  })
  .then(function (result) {

    return {sprint: sprint, stories: stories, calculations: {remaining_time: remaining_times, time_spent: times_spent, task_count: result}};
  });
};

var extractHeaderField = function(field, headers) {

  var value = headers[field];
  if (value === undefined) {

    throw 'header field "' + field + '" missing in request';
  }
  return value;
};

var extractRev = _.compose(u.partial(ensure, _.isFinite, '"rev" header in request is malformed.'), u.curry2(parseInt)(10), u.partial(extractHeaderField, 'rev'));

var extractParentId = u.partial(extractHeaderField, 'parent_id');

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

var calculationQuery = function(dbFn, id) {

  return dbFn([id])
  .then(function (result) {

    return _.last(_.first(result));
  });
};

var processRequest = function(request, response) {

  var query, answer, id, parentId, rev, property, filter;
  var url_parts = url.parse(request.url, true);
  var urlQuery = url_parts.query;
  var pathname = url_parts.pathname;
  var pathParts = pathname.split("/");
  var type = (pathParts.length > 1 && pathParts[1] !== "") ? unescape(pathParts[1]) : 'index';
  var method = request.method;
  id = pathParts.length > 2 ? unescape(pathParts[2]) : null;
  var html = ((request.headers.accept !== undefined) && (request.headers.accept.match(/application\/json/) !== null)) ? false : true;
  var respond = html ? u.partial(respondWithHtml, response, type) : u.partial(respondWithJson, response);

  // simple json get requests
  if ((!html) && (method == 'GET') && (_.contains(['task', 'story', 'sprint'], type))) {

    filter = {};
    if (request.headers.parent_id) {

      if (type == 'task') {

        filter.story_id = ObjectID(request.headers.parent_id);
      }
      else if (type == 'story') {

        filter.sprint_id = ObjectID(request.headers.parent_id);
      }
    }

    var sort = {};
    if (request.headers.sort_by) {

      sort[request.headers.sort_by] = 1;
    }
    
    query = (id) ? u.partial(tischDB.findOne, type, id) : u.partial(tischDB.find, type, filter, sort);
    answer = u.partial(respondWithJson, response);
  }
  else if ((type == 'task') && (request.method == 'GET')) {

    query = u.partial(taskViewQuery, id);
    answer = respond;
  }
  else if ((type == 'task') && (request.method == 'POST')) {

    rev = extractRev(request.headers);

    query = (request.body.key == 'story_id') ? u.partial(tischDB.updateTaskAssignment, id, request.body.value, rev) : u.partial(tischDB.updateTask, id, rev, request.body.key, request.body.value);
    answer = u.partial(postAnswer, request.body.key, 'story_id', u.partial(respondWithJson, response));
  }
  else if ((type == 'task') && (request.method == 'PUT')) {

    // TODO: check client_uuid header for all non-get requests!
    parentId = extractParentId(request.headers);

    query = u.partial(addQuery, tischDB.insertTask, constants.templates.task, 'story_id', parentId);
    answer = u.partial(putAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'task') && (request.method == 'DELETE')) {
      
    rev = extractRev(request.headers);

    query = u.partial(removeTaskQuery, id, rev);
    answer = u.partial(deleteAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'story') && (request.method == 'GET')) {

    query = u.partial(storyViewQuery, id);
    answer = respond;
  }
  else if ((type == 'story') && (request.method == 'POST')) {

    rev = extractRev(request.headers);

    query = (request.body.key == 'sprint_id') ? u.partial(tischDB.updateStoryAssignment, id, request.body.value, rev) : u.partial(tischDB.updateStory, id, rev, request.body.key, request.body.value);
    answer = u.partial(postAnswer, request.body.key, 'sprint_id', u.partial(respondWithJson, response));
  }
  else if ((type == 'story') && (request.method == 'PUT')) {

    parentId = extractParentId(request.headers);

    query = u.partial(addQuery, tischDB.insertStory, constants.templates.story, 'sprint_id', parentId);
    answer = u.partial(putAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'story') && (request.method == 'DELETE')) {

    rev = extractRev(request.headers);

    query = function() {

      var story;
      filter = {_id: ObjectID(id), _rev: rev};

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

    answer = u.partial(deleteAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'sprint') && (request.method == 'GET')) {

    query = u.partial(sprintViewQuery, id);
    answer = respond;
  }
  else if ((type == 'sprint') && (request.method == 'POST')) {

    rev = extractRev(request.headers);

    if (request.body.key == 'start') {

      request.body.value = new Date(request.body.value);
    }

    query = u.partial(tischDB.updateSprint, id, rev, request.body.key, request.body.value);
    answer = u.partial(postAnswer, request.body.key, null, u.partial(respondWithJson, response));
  }
  else if ((type == 'sprint') && (request.method == 'PUT')) {

    var data = _.clone(constants.templates.sprint);
    data.start = moment().millisecond(0).second(0).minute(0).hour(0).toDate();

    query = u.partial(addQuery, tischDB.insertSprint, data, null, 'index');
    answer = u.partial(putAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'sprint') && (request.method == 'DELETE')) {
  
    rev = extractRev(request.headers);

    query = function() {

      filter = {_id: ObjectID(id), _rev: rev};
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

    answer = u.partial(deleteAnswer, u.partial(respondWithJson, response));
  }
  else if ((type == 'index') && (request.method == 'GET')) {

    query = indexViewQuery;
    answer = respond;
  }
  else if (id && (type == 'calculation') && (request.method == 'GET') && (urlQuery.func == 'time_spent_for_story')) {

    // TODO: robustness, check for start & end query

    query = u.partial(calculationQuery, u.curry2(tischDB.getStoriesTimeSpent)({start: urlQuery.start, end: urlQuery.end}), id);
    answer = u.partial(respondWithJson, response);
  }
  else if (id && (type == 'calculation') && (request.method == 'GET') && (urlQuery.func == 'task_count_for_story')) {

    query = u.partial(calculationQuery, tischDB.getStoriesTaskCount, id);
    answer = u.partial(respondWithJson, response);
  }
  else if (id && (type == 'calculation') && (request.method == 'GET') && (urlQuery.func == 'remaining_time_for_story')) {

    // TODO: robustness, check for start & end query

    query = u.partial(calculationQuery, u.curry2(tischDB.getStoriesRemainingTime)({start: urlQuery.start, end: urlQuery.end}), id);
    answer = u.partial(respondWithJson, response);
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
  .then(u.partial(notify, request))
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

  tischDB.init()
  .then(function() {

    var port = (process.env.NODE_ENV == 'test') ? 8001 : 8000;
    var server = http.createServer(app).listen(port, function() {
    
      console.log('Server listening on port ' + port);
      tischRT.listen(server);
    });
  });
};

module.exports = app;

if (!module.parent) {

  app.start();
}
