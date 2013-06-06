$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    addItem("task", parentId);
  }); 

  $('.panel').on('click', '.save-button', function(event) {
  
    event.preventDefault();

    var task = $(event.delegateTarget);
    var dbAttributes = task.data('attributes');
    var id = dbAttributes._id;
    var summary = $('input', story).val();
    var description = $('textarea', story).val();
    
    var webAttributes = {

      summary: summary,
      description: description,
      priority: task.data('priority')
    };

    var delta = buildPostDelta(webAttributes, dbAttributes);

    var rev = dbAttributes._rev;
    updateItem(id, rev, 'task', delta);
  });
  
  $('.main-panel').on('click', '.save-button', function(event) {
   
    event.preventDefault();

    var story = $(event.delegateTarget);
    var dbAttributes = story.data('attributes');
    var id = dbAttributes._id;
    var title = $('input', story).val();
    var description = $('textarea', story).val();

    var webAttributes = {

      title: title,
      description: description,
    };

    var delta = buildPostDelta(webAttributes, dbAttributes);

    var rev = dbAttributes._rev;
    updateItem(id, rev, 'story', delta);
  });
});
