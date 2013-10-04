var updateColor = function(item, color) {

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
});