var updateTitle = function(item, text) {

	var input = $('input[name="title"]', item);
	if (isUpdateOk(input, text)) {

		input.val(text);
		input.trigger('input.autogrow');
	}
}

var updateDescription = function(item, text) {

	var textarea = $('textarea[name="description"]', item);
	if (isUpdateOk(textarea, text)) {

		textarea.val(text);	
	}
}

var updatePriority = function(item, priority) {

	sortPanels();	
}

var updateEstimation = function(item, text) {

 	var input = $('input[name="estimation"]', item);
	if (isUpdateOk(input, text)) {

		input.val(text);	
	}
}

var updateSummary = function(item, text) {

	var input = $('input[name="summary"]', item);
	if (isUpdateOk(input, text)) {

		input.val(text);	
	}
}

var updateColor = function(item, color) {

   $('.header, .header input, #color-selector .selected', item).removeClass(COLORS.join(' ')).addClass(color);  
}

$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    requestAdd("task", parentId);
  });

  $('#panel-template').data('type', 'task');

  $('input[name="estimation"]').data('parser', timeParser);

  initColorSelector();
  
	$('.main-panel').data('update', {

		title: updateTitle,
		description: updateDescription,
		estimation: updateEstimation,
		color: updateColor
	});

	$('.panel').data('update', {

		summary: updateSummary,
		description: updateDescription,
		priority: updatePriority,
		color: updateColor
	});
});
