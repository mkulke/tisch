var common, ractive, socketio, taskView;

common = (function() {
  var COLORS, uuid;
  COLORS = ['yellow', 'orange', 'red', 'purple', 'blue', 'green'];
  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r, v;
    r = Math.random() * 16 | 0;
    v = c === 'x' ? r : r & 0x3 | 0x8;
    return v.toString(16);
  });
  return {
    COLORS: COLORS,
    uuid: uuid
  };
})();

socketio = (function() {
  var init;
  init = function() {
    var socket;
    socket = io.connect('http://' + window.location.hostname);
    socket.on('connect', function() {
      return socket.emit('register', {
        client_uuid: common.uuid
      });
    });
    return socket.on('message', function() {
      if (data.recipient === task._id) {
        if (data.message === 'update') {
          ractive.set('task._rev', data.data._rev);
          return ractive.set('task.' + data.data.key, data.data.value);
        }
      }
    });
  };
  return {
    init: init
  };
})();

socketio.init();

ractive = (function() {
  var get, init, set, startUpdateTimer;
  init = function(template) {
    ractive = new Ractive({
      el: 'output',
      template: template,
      data: {
        task: taskView.objects().task,
        COLORS: common.COLORS,
        stories: [taskView.objects().story]
      }
    });
    ractive.on({
      keypress: startUpdateTimer,
      keypress_ignore_return: function(event) {
        if (event.original.which === 13) {
          event.original.preventDefault();
        }
        return startUpdateTimer(event);
      },
      focusout: function(event) {
        clearTimeout(keyboardTimer);
        return taskView.commitUserInput.call(event.node);
      },
      select_focus: taskView.populateStorySelector
    });
    ractive.observe('task.color', taskView.commitUserInput.bind($('#color').get(0)), {
      init: false
    });
    ractive.observe('task.story_id', taskView.commitUserInput.bind($('#story_id').get(0)), {
      init: false
    });
    $('input, textarea, select').each(function() {
      return $(this).data('confirmed_value', taskView.objects().task[this.id]);
    });
    return $('#initial_estimation').data('validation', function(value) {
      return value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) === 0;
    });
  };
  startUpdateTimer = function(event) {
    var keyboardTimer;
    clearTimeout(keyboardTimer);
    return keyboardTimer = setTimeout(taskView.commitUserInput.bind(event.node, 1500));
  };
  set = function(keypath, value) {
    return ractive.set(keypath, value);
  };
  get = function(keypath) {
    return ractive.get(keypath);
  };
  return {
    init: init,
    set: set,
    get: get
  };
})();

taskView = (function() {
  var commitUserInput, init, objects, populateStorySelector, requestUpdate, story, task;
  task = story = null;
  init = function(aTask, aStory) {
    task = aTask;
    return story = aStory;
  };
  populateStorySelector = function() {
    var sprint_id, _i, _len, _ref;
    _ref = ractive.get('stories');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      story = _ref[_i];
      if (story._id === task.story_id) {
        sprint_id = story.sprint_id;
      }
    }
    return $.ajaxq('client', {
      url: '/story',
      type: 'GET',
      headers: {
        parent_id: sprint_id
      },
      dataType: 'json'
    }, success(function(data, textStatus, jqXHR) {
      return ractive.set('stories', data);
    }), error(function(data, textStatus, jqXHR) {
      return alert('error!');
    }));
  };
  commitUserInput = function() {
    var key, value;
    if ($(this).data('validation') != null) {
      if (!$(this).data('validation')($(this).val())) {
        task[this.id] = $(this).data('confirmed_value');
        $(this).next().show();
        false;
      } else {
        $(this).next().hide();
      }
    }
    key = this.id;
    value = task[key];
    return requestUpdate(key, value, function(value) {
      return $(this).data('confirmed_value', value);
    }, function() {
      return ractive.set("task." + this.id, $(this).data('confirmed_value'));
    });
  };
  requestUpdate = function(key, value, successCb, undoCb) {
    return $.ajaxq('client', {
      url: "/task/" + task._id,
      type: 'POST',
      headers: {
        client_uuid: common.uuid
      },
      contentType: 'application/json',
      data: JSON.stringify({
        key: key,
        value: value
      }),
      beforeSend: function(jqXHR, settings) {
        return jqXHR.setRequestHeader('rev', task._rev);
      },
      success: function(data, textStatus, jqXHR) {
        ractive.set('task._rev', data.rev);
        ractive.set("task." + key, data.value);
        if (successCb != null) {
          return successCb(data.value);
        }
      },
      error: function(data, textStatus, jqXHR) {
        alert('error!');
        if (undoCb != null) {
          return undoCb();
        }
      }
    });
  };
  objects = function() {
    return {
      task: task,
      story: story
    };
  };
  return {
    init: init,
    commitUserInput: commitUserInput,
    populateStorySelector: populateStorySelector,
    objects: objects
  };
})();

/*
//@ sourceMappingURL=whack.js.map
*/