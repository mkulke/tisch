/*var updateColor = function(item, color) {

  $('#color-selector .selected', item).removeClass(COLORS.join(' ')).addClass(color);
};

var updateStoryId = function(item, id) {

  var selector = $('#story-selector', item);

  $.ajaxq('client', {

    url: '/story/' + id,
    type: 'GET',
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {

      var label = data[selector.data('name')];
      $('span.selected', selector).text(label);
      $('span.selected', selector).data('attributes', data);
      $('span.selected', selector).attr('id', prefix(data._id));
    },
    error: handleServerError
  });
};

var remainingTimeParser = function(value) {

  return $('.main-panel').data('attributes').remaining_time;
}

$(document).ready(function() {
  
  $('#date-selector span.selected').html('today');
  initDateSelector($('#date-selector'), function(dateText, inst) {

    alert('Selected ' + dateText);
  });
  // Only allow sprint days for selection.
  $('#date-selector .selected').bind('click', function(event) {

    var sprint_id = $('#story-selector span.selected').data('attributes').sprint_id;

    $.ajaxq('client', {

      url: '/sprint/' + sprint_id,
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        var minDate = new Date(data.start);
        var maxDate = new Date(minDate.getTime() + (data.length * MS_DAYS_FACTOR));
        $('#date-selector .content').datepicker('option', 'minDate', minDate);
        $('#date-selector .content').datepicker('option', 'maxDate', maxDate);
        $('#date-selector .content').css('visibility', 'visible');
      },
      error: handleServerError
    });
  });

  // TODO: make that generic?
  $('#story-selector').data('name', 'title');    
  initPopupSelector($('#story-selector'), 'story_id', function(fillIn) {

    var sprint_id = $('#story-selector span.selected').data('attributes').sprint_id;

    $.ajaxq('client', {

      url: '/story',
      type: 'GET',
      headers: {parent_id: sprint_id},
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        fillIn(data);
        $('#story-selector .content .line').bind('click', $('.main-panel'), function(event) {

          var task = event.data;
          var line = $(event.target);
          var storyId = line.data('id');

          requestUpdate(task, 'story_id', storyId);
        });
      },
      error: handleServerError
    });
  });    
  
  initColorSelector();

  // make sure story title changes are reflected in the view.
  $('#story-selector span.selected').data('gui_handlers', { update: function(data) { 

    if (data.key == 'title') {

      $('#story-selector span.selected').data('attributes').title = data.value;     
      $('#story-selector span.selected').text(data.value);     
    }
  }});

  $('input[name="initial_estimation"], input[name="time_spent"]').data('parser', timeParser);
  $('input[name="remaining_time"]').data('parser', remainingTimeParser);


  var updateFunctions = {color: updateColor, story_id: updateStoryId};  
  $.each(['summary', 'description', 'initial_estimation', 'remaining_time', 'time_spent'], function(index, value) {

    updateFunctions[value] = function(item, text) {

      var inputOrTextarea = $('input[name="' + value + '"], textarea[name="' + value + '"]', item);

      if (isUpdateOk(inputOrTextarea, text)) {

        inputOrTextarea.val(text);
        inputOrTextarea.trigger('input.autogrow');
      }
    };
  });
  $('.main-panel').data('update', updateFunctions);
});*/

/*common = function() {

  var COLORS = ['yellow', 'orange', 'red', 'purple', 'blue', 'green'];

  var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {

    var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
    return v.toString(16);
  });

  return {COLORS: COLORS, uuid: uuid};
}();*/

/*ractive = function() {

  var keyboardTimer;
  var ractive;

  var init = function (template) {

    ractive = new Ractive({

      el: 'output',
      template: template,
      data: { 

        task: taskView.objects().task,
        COLORS: common.COLORS,
        stories: [taskView.objects().story],
      }
    });

    ractive.on({

      keypress: startUpdateTimer,
      keypress_ignore_return: function (event) {

        if (event.original.which == 13) {
        
          event.original.preventDefault();
        }
        startUpdateTimer(event);
      },
      focusout: function(event) {

        clearTimeout(keyboardTimer);
        taskView.commitUserInput.call(event.node);
      },
      select_focus: taskView.populateStorySelector
    });

    ractive.observe('task.color', taskView.commitUserInput.bind($('#color').get(0)), {init: false});
    ractive.observe('task.story_id', taskView.commitUserInput.bind($('#story_id').get(0)), {init: false});

    $('input, textarea, select').each(function() {

      $(this).data('confirmed_value', taskView.objects().task[this.id]);
    });
    $('#initial_estimation').data('validation', function(value) {

      return (value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) === 0);
    });
  };

  var startUpdateTimer = function(event) {

    clearTimeout(keyboardTimer);
    keyboardTimer = setTimeout(taskView.commitUserInput.bind(event.node), 1500);
  };

  var set = function(keypath, value) {

    ractive.set(keypath, value);
  };

  var get = function(keypath) {

    return ractive.get(keypath);
  };

  return {init: init, set: set, get: get};
}();*/

/*taskView = function() {

  var task;
  var story;

  var init = function(aTask, aStory) {

    task = aTask;
    story = aStory;
  };

  var populateStorySelector = function() {

    var sprint_id = $.map(ractive.get('stories'), function(story) {

      return (story._id == task.story_id) ? story.sprint_id : null;
    })[0];

    $.ajaxq('client', {

      url: '/story',
      type: 'GET',
      headers: {parent_id: sprint_id},
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        ractive.set('stories', data);
      },
      error: function(data, textStatus, jqXHR) {

        alert('error!');
      }
    });
  };

  var commitUserInput = function() {

    if ($(this).data('validation')) {

      if (!$(this).data('validation')($(this).val())) {

        task[this.id] = $(this).data('confirmed_value');
        $(this).next().show();
        return false;
      }
      else {

        $(this).next().hide();      
      }
    }

    var key = this.id;
    var value = task[key];

    requestUpdate(key, value, function(value) {

      $(this).data('confirmed_value', value);
    }, function() {

      ractive.set('task.' + this.id, $(this).data('confirmed_value'));
    });
  };

  var requestUpdate = function(key, value, successCb, undoCb) {

    var id = task._id;

    $.ajaxq('client', {
      
      url: '/task/' + id,
      type: 'POST',
      headers: {client_uuid: common.uuid},
      contentType: 'application/json',
      data: JSON.stringify({key: key, value: value}),
      beforeSend: function(jqXHR, settings) {

        jqXHR.setRequestHeader('rev', task._rev);
      },
      success: function(data, textStatus, jqXHR) {

        ractive.set('task._rev', data.rev);
        ractive.set('task.' + key, data.value);
        if (successCb) {

          successCb(data.value);
        }
      },
      error: function(data, textStatus, jqXHR) {

        alert('error!');
        if (undoCb) {

          undoCb();
        }
      }
    });
  };

  var objects = function() {

    return {task: task, story: story};
  };

  return {init: init, commitUserInput: commitUserInput, populateStorySelector: populateStorySelector, objects: objects};
}();*/


