$(document).ready(function() {
    
  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    addItem("story", parentId);
  });

  $('.panel').on('click', '.save-button', function(event) {

    event.preventDefault();

    var story = $(event.delegateTarget);
    var dbAttributes = story.data('attributes');
    var id = dbAttributes._id;
    var title = $('input', story).val();
    var description = $('textarea', story).val();
    
    var webAttributes = {

      title: title,
      description: description,
      priority: story.data('priority')
    };

    var delta = buildPostDelta(webAttributes, dbAttributes);

    var rev = dbAttributes._rev;
    updateItem(id, rev, 'story', delta);
  });
  
  $('.main-panel').on('click', '.save-button', function(event) {
   
    event.preventDefault();

    var sprint = $(event.delegateTarget);
    var dbAttributes = sprint.data('attributes');
    var id = dbAttributes._id;
    var title = $('input', sprint).val();
    var description = $('textarea', sprint).val();
    
    var webAttributes = {

      title: title,
      description: description,
    };

    var delta = buildPostDelta(webAttributes, dbAttributes);

    var rev = dbAttributes._rev;
    updateItem(id, rev, 'sprint', delta);
  }); 
});
