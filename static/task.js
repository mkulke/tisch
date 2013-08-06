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

$(document).ready(function() {
  
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

  $('input[name="initial_estimation"], input[name="remaining_time"], input[name="time_spent"]').data('parser', timeParser);

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