$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    requestAdd("task", parentId);
  });

  $('#panel-template').data('type', 'task');

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

  var updateEstimation = function(item, text) {

  	$('input[name="estimation"]', item).val(text);	
  }

  $('input[name="estimation"]').data('parser', timeParser);

  initColorSelector();
  
	$('.main-panel').data('update', {

		title: updateTitle,
		description: updateDescription,
		estimation: updateEstimation,
		color: updateColor
	});

  var updateSummary = function(item, text) {

  	$('input[name="summary"]', item).val(text);	
  }

	$('.panel').data('update', {

		summary: updateSummary,
		description: updateDescription,
		priority: updatePriority,
		color: updateColor
	});
});
