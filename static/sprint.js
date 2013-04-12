$(document).ready(function() {
    
  $('.panel').on('click', '.save-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = story.attr('id');
    var title = $('input', story).val();
    var description = $('textarea', story).val();

    var post_data = itemMap[id];
    post_data['title'] = title;
    post_data['description'] = description;
    
    update_item(id, 'story', post_data);
  });
  
  $('.main-panel').on('click', '.save-button', function(event) {
   
    var sprint = $(event.delegateTarget);
    var id = sprint.attr('id');
    var title = $('input', sprint).val();
    var description = $('textarea', sprint).val();

    var post_data = itemMap[id];
    post_data['title'] = title;
    post_data['description'] = description;
    
    update_item(id, 'sprint', post_data);
  });
  
  $('.panel').on('click', '.open-button', function(event) {

    var story = $(event.delegateTarget);
    var id = story.attr('id');
    window.location.href = "/story/" + id;
  });   
});
