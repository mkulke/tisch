var taskMap = {}

function populate_map(tasks) {

  $.each(tasks, function(i, task) {
  
    taskMap[task._id] = task;
  });
}

$(document).ready(function() {
 
  $('.panel').on('click', '.save-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = story.attr('id');
    var summary = $('input', story).val();
    var description = $('textarea', story).val();

    var post_data = storyMap[id];
    post_data['summary'] = summary;
    post_data['description'] = description;
    
    $.ajax({
    
      url: '/task/' + id,
      type: 'POST',
      dataType: 'json',
      data: post_data,
      success: function(data, textStatus, jqXHR) {
      
        storyMap[id] = data;
        $('.save-button', story).hide();
      },
      error: function(jqHXR, textStatus, errorThrown) {
        
        switch(textStatus) {
        
          case 'timeout':
            
            var errorMessage = 'Operation timed out. Possible reasons include network and server issues.';
            break;
          case 'error':
            
            var errorMessage = 'Operation failed. ' + errorThrown;
            break;
          default:
            
            var errorMessage = 'Operation failed for unknown reasons. Check server logs.';
        }
        $('#error-panel #message').text(errorMessage);
        $('#error-panel').slideDown(100);
      }
    });
  });
});
