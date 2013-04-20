$(document).ready(function() {
 
  $('.panel').on('click', '.save-button', function(event) {
  
    var task = $(event.delegateTarget);
    var id = task.attr('id');
    var summary = $('input', task).val();
    var description = $('textarea', task).val();

    var post_data = itemMap[id];
    post_data['summary'] = summary;
    post_data['description'] = description;
    
    updateItem(id, 'task', post_data);
  });
});
