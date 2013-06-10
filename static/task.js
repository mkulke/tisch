$(document).ready(function() {
  
  initPopupSelector($('#story-selector'), 'story_id', function(fillIn) {
    
    var sprint_id = $('#story-selector').data('sprint_id');

    $.ajax({

      url: '/story',
      type: 'GET',
      headers: {parent_id: sprint_id},
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        fillIn(data);
      },
      error: handleServerError
    });
  });    
           
  $('.main-panel').on('click', '.save-button', function(event) {
   
    event.preventDefault();

    var task = $(event.delegateTarget);
    var dbAttributes = task.data('attributes');
    var id = dbAttributes._id;

    var summary = $('input[name="summary"]', task).val();
    var description = $('textarea', task).val();
    var initialEstimation = $('input[name="initial_estimation"]', task).val();
    var remainingTime = $('input[name="remaining_time"]', task).val();
    var timeSpent = $('input[name="time_spent"]', task).val();
    var storyId = $('#story-selector').data('selected');

    try {
     
      function isValidNumber(value, name) {
      
        var result = value.match(/^\d{1,2}(\.\d{1,2}){0,1}$/);
        if (!result) {
    
          throw name + ' must be specified as a positive number < 100 with not more than two precision digits (e.g. "1" or "99.25").';
        }
      }
     
      isValidNumber(initialEstimation, "Initial estimation");    
      isValidNumber(remainingTime, "Remaining time");
      isValidNumber(timeSpent, "Time spent");
      
      var webAttributes = {

        summary: summary,
        description: description,
        initial_estimation: parseFloat(initialEstimation, 10),
        remaining_time: parseFloat(remainingTime, 10),
        time_spent: parseFloat(timeSpent, 10),
        story_id: storyId
      };

      var delta = buildPostDelta(webAttributes, dbAttributes);
    
      var rev = dbAttributes._rev;
      updateItem(id, rev, 'task', delta);
    } catch (e) {
    
      showErrorPanel(e);
    }
  });
});