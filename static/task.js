$(document).ready(function() {
  
  initPopupSelector($('#story-selector'), function(fillIn) {
    
    $.ajax({

      url: '/story',
      type: 'GET',
      success: function(data, textStatus, jqXHR) {

        fillIn(data);
      },
      error: handleServerError
    });
  });    
           
  $('.main-panel').on('click', '.save-button', function(event) {
   
    var task = $(event.delegateTarget);
    var id = unPrefix(task.attr('id'));
    var summary = $('input[name="summary"]', task).val();
    var description = $('textarea', task).val();
    var initialEstimation = $('input[name="initial_estimation"]', task).val();
    var remainingTime = $('input[name="remaining_time"]', task).val();
    var timeSpent = $('input[name="time_spent"]', task).val();

    try {
     
      function isValidNumber(value, name) {
      
        var result = value.match(/^\d{1,2}(\.\d{1,2}){0,1}$/);
        if (result == null) {
    
          throw name + ' must be specified as a positive number < 100 with not more than two precision digits (e.g. "1" or "99.25").';
        }
      }
     
      isValidNumber(initialEstimation, "Initial estimation");    
      isValidNumber(remainingTime, "Remaining time");
      isValidNumber(timeSpent, "Time spent");
      
      post_data = itemMap[id];
      post_data['initial_estimation'] = initialEstimation;
      post_data['remaining_time'] = remainingTime;
      post_data['time_spent'] = timeSpent;
      post_data['summary'] = summary;
      post_data['description'] = description;
    
      updateItem(id, 'task', post_data)
    } catch (e) {
    
      showErrorPanel(e);
    }
  });
});