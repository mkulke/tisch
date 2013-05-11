$(document).ready(function() {

  $('.panel').on('click', '.remove-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = story.attr('id');
    var post_data = itemMap[id];
    
    removeItem(id, 'story', post_data);
  });
    
  $('.panel').on('click', '.save-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = story.attr('id');
    var title = $('input', story).val();
    var description = $('textarea', story).val();

    var post_data = itemMap[id];
    post_data['title'] = title;
    post_data['description'] = description;
    
    updateItem(id, 'story', post_data);
  });
  
  $('.main-panel').on('click', '.save-button', function(event) {
   
    var sprint = $(event.delegateTarget);
    var id = sprint.attr('id');
    var title = $('input', sprint).val();
    var description = $('textarea', sprint).val();

    var post_data = itemMap[id];
    post_data['title'] = title;
    post_data['description'] = description;
    
    updateItem(id, 'sprint', post_data);
  });
  
  /*$('.panel').on('click', '.open-button', function(event) {

    var story = $(event.delegateTarget);
    var id = story.attr('id');
    window.location.href = "/story/" + id;
  });*/
  
  $('.panel .handle').on('dblclick', function(event) {
  
    var handle = $(event.delegateTarget);
    var story = handle.parents('li').first();
    var id = story.attr('id');
    window.location.href = "/story/" + id;
  });
  
  $('#add-button').on('click', function(event) {
   
    var sprint = $('.main-panel').first();
    var id = sprint.attr('id');
    addItem(id, 'sprint');
  });   
});
