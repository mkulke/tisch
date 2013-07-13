var MS_DAYS_FACTOR = 86400000;

function buildDateString(date) {

	return (date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2);
}

function updateStart(item, dateText) {

	var date = new Date(dateText);
	item.data('attributes').start = date;

	var length = $('.main-panel').data('attributes').length;
	var endDate = new Date(date.getTime() + (length * MS_DAYS_FACTOR));

	$('#start-selector span.selected').html(buildDateString(date));
	$('#length-selector span.selected').html(buildDateString(endDate));	
}

function updateLength(item, length) {

	item.data('attributes').length = length;

	var startDate = $('.main-panel').data('attributes').start;
	var date = new Date(startDate.getTime() + (length * MS_DAYS_FACTOR));

	$('#length-selector span.selected').html(buildDateString(date));	
}

$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    var parentId = $('.main-panel').data('attributes')._id;
    requestAdd("story", parentId);
  });

  $('#panel-template').data('type', 'story');

  var updateTitle = function(item, text) {

    var input = $('input[name="title"]', item);
    if (isUpdateOk(input, text)) {

      input.val(text);  
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

  initColorSelector();

  var updateColor = function(item, color) {

    $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(color);	
  }

	$.each(['start', 'length'], function(index, value) {

		var id = '#' + value + '-selector';
		var selector = $(id);

	  // position popup, TODO: adjust the arrow pointing according to css
	  var left = $('.open', selector).offset().left - 17;
	  var offset = $('a > .content', selector).offset();
	  offset.left = left;
	  $('a > .content', selector).offset(offset);

	  var closeHandler = function(event) {

	    if (($(event.target).parents(id + '.popup-selector').length < 1) && (($(event.target).parents('.ui-datepicker-header').length < 1))) {    
	  
	      $('.content', selector).css("visibility", "hidden");
	      $(document).unbind('click', closeHandler);
	    }
  	};

		$('.content', selector).datepicker({  

		  inline: true,  
		  showOtherMonths: true,  
		  dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
		  nextText: '>',
		  prevText: '<',
		  dateFormat: $.datepicker.ISO_8601,
		  gotoCurrent: true,
		  onSelect: function(dateText, inst) { 

		  	$('.content', selector).css("visibility", "hidden");
	      $(document).unbind('click', closeHandler);
		  	
	      var date = new Date(dateText);
	      var item = $('.main-panel');

	      if (value == 'start') {

	      	requestUpdate(item, 'start', date.toString());	
	      }
	      else {

	      	var startDate = item.data('attributes').start;
	      	// TODO: sanity check
	      	var dayDelta = (date - startDate) / MS_DAYS_FACTOR;

	      	requestUpdate(item, 'length', dayDelta);  
	      }
		  }
		});

  	$('.selected', selector).bind('click', function(event) {

      $(document).bind('click', closeHandler);
    });
	});

	$('#start-selector .selected').bind('click', function(event) {

		var date = $('.main-panel').data('attributes').start;
		$('#start-selector .content').datepicker('setDate', date);
		$('#start-selector .content').css('visibility', 'visible');  
	});

	$('#length-selector .selected').bind('click', function(event) {

		var startDate = $('.main-panel').data('attributes').start;
		var date = new Date(startDate.getTime() + ($('.main-panel').data('attributes').length * MS_DAYS_FACTOR));

		$('#length-selector .content').datepicker('setDate', date);    
		// Ensure there cannot be selected a date before the start.
		$('#length-selector .content').datepicker('option', 'minDate', $('.main-panel').data('attributes').start);
		$('#length-selector .content').css('visibility', 'visible');    
	});

  $('.main-panel').data('update', {

  	title: updateTitle, 
  	description: updateDescription,
  	color: updateColor,
  	start: updateStart,
  	length: updateLength
  });

	$('.panel').data('update', {

		title: updateTitle, 
		description: updateDescription, 
		priority: updatePriority,
		color: updateColor
	});
});
