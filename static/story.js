$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    requestAdd("task", parentId);
  });

  $('input[name="estimation"]').data('parser', timeParser);

  initColorSelector();
});
