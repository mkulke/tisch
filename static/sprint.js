$(document).ready(function() {
    
  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    requestAdd("story", parentId);
  });

  $('#panel-template').data('type', 'story');

  var updateTitle = function(item, text) {

  	$('input[name="title"]', item).val(text);	
  }

  var updateDescription = function(item, text) {

  	$('textarea[name="description"]', item).val(text);	
  }

  var updatePriority = function(item, priority) {

  	sortPanels();	
  }

  var updateColor = function(item, color) {

    $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(color);	
  }

  $('.main-panel').data('update', {title: updateTitle, description: updateDescription});


	$('.panel').data('update', {

		title: updateTitle, 
		description: updateDescription, 
		priority: updatePriority,
		color: updateColor
	});
});
