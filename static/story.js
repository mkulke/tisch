$(document).ready(function() {
    
  $('.panel').on('click', '.save-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = unPrefix(story.attr('id'));
    var summary = $('input', story).val();
    var description = $('textarea', story).val();

    var post_data = itemMap[id];
    post_data.summary = summary;
    post_data.description = description;
    
    updateItem(id, 'task', post_data);
  });
  
  $('.main-panel').on('click', '.save-button', function(event) {
   
    var sprint = $(event.delegateTarget);
    var id = unPrefix(sprint.attr('id'));
    var title = $('input', sprint).val();
    var description = $('textarea', sprint).val();

    var post_data = itemMap[id];
    post_data.title = title;
    post_data.description = description;
    
    updateItem(id, 'story', post_data);
  });
});
