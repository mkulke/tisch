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
  
  $('.panel').on('dblclick', function(event) {

    var story = $(event.delegateTarget);
    var id = story.attr('id');
    window.location.href = "/story/" + id;
  });   
});
