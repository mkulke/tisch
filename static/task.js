 $(document).ready(function() {
  
  // TODO: make that generic?
  $('#story-selector').data('name', 'title');    
  initPopupSelector($('#story-selector'), 'story_id', function(fillIn) {

    var sprint_id = $('#story-selector').data('selected').parent_id;

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
          var storyId = line.data('id')

          requestUpdate(task, {story_id: storyId});
        });
      },
      error: handleServerError
    });
  });    
  
  initColorSelector();

  $('input[name="initial_estimation"], input[name="remaining_time"], input[name="time_spent"]').data('parser', timeParser);
});