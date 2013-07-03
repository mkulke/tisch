 $(document).ready(function() {
  
  // TODO: make that generic?
  $('#story-selector').data('name', 'title');    
  initPopupSelector($('#story-selector'), 'story_id', function(fillIn) {

    var sprint_id = $('#story-selector').data('selected').sprint_id;

    $.ajax({

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

  $('input[name="initial_estimation"], input[name="remaining_time"], input[name="time_spent"]').data('parser', timeParser);

  var updateFunctions = {};
  $('.main-panel').data('update', updateFunctions);
  
  updateFunctions.color = function(item, color) {

    $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(color);
  };

  updateFunctions.story_id = function(item, id) {

    var selector = $('#story-selector', item);

    $.ajaxq('client', {

      url: '/story/' + id,
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        var label = data[selector.data('name')];
        $('.open span', selector).text(label);
        selector.data('selected', data);
      },
      error: handleServerError
    });
  };

  $.each(['summary', 'description', 'initial_estimation', 'remaining_time', 'time_spent'], function(index, value) {

    updateFunctions[value] = function(item, text) {

      $('input[name="' + value + '"], textarea[name="' + value + '"]', item).val(text);
    };
  });
});