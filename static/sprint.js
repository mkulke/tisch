function buildDateString(date) {

	return (date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2);
}

function updateStart(item, dateText) {

	var date = new Date(dateText);
	item.data('attributes').start = date;

	var length = item.data('attributes').length;
	var endDate = new Date(date.getTime() + (length * MS_DAYS_FACTOR));

	$('#start-selector span.selected', item).html(buildDateString(date));
	$('#length-selector span.selected', item).html(buildDateString(endDate));	
}

function updateLength(item, length) {

	item.data('attributes').length = length;

	var startDate = item.data('attributes').start;
	var date = new Date(startDate.getTime() + (length * MS_DAYS_FACTOR));

	$('#length-selector span.selected', item).html(buildDateString(date));	
}

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

var updateColor = function(item, color) {

	$('.stripe, #color-selector .selected', item).removeClass(COLORS.join(' ')).addClass(color);  
}

var updateRemainingTimeCalculation = function(item, remainingTime) {

	$('.header span.remaining.text', item).html(remainingTime);

	if (remainingTime === null) {

		$('.header .remaining', item).hide();
		$('.header .done', item).hide();
	}
	else if (remainingTime === 0) {

		$('.header .remaining', item).hide();
		$('.header .done', item).show();
	}
	else {

		$('.header .remaining', item).show();
		$('.header .done', item).hide();
	}
}

var requestRemainingTimeCalculation = function(id) {

  $.ajaxq('client', {

    url: '/remaining_time_calculation/' + id,
    type: 'GET',
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {

    	updateRemainingTimeCalculation($('#' + prefix(id)), data);
    },
    error: handleServerError
  });
}

$(document).ready(function() {

	/*var ctx = document.getElementById("testchart").getContext("2d");

	var data = {
		labels : ["January","February","March","April","May","June","July"],
		datasets : [
			{
				fillColor : "rgba(220,220,220,0.5)",
				strokeColor : "rgba(220,220,220,1)",
				pointColor : "rgba(220,220,220,1)",
				pointStrokeColor : "#fff",
				data : [65,59,90,81,56,55,40]
			},
			{
				fillColor : "rgba(151,187,205,0.5)",
				strokeColor : "rgba(151,187,205,1)",
				pointColor : "rgba(151,187,205,1)",
				pointStrokeColor : "#fff",
				data : [28,48,40,19,96,27,100]
			}
		]
	}

	new Chart(ctx).Line(data);*/

	initColorSelector();

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();

   	requestAdd($('.main-panel'));
  });

  $('#panel-container').data('sort', function (a, b) {

    return $(a).data('attributes').priority - $(b).data('attributes').priority;  
  });

  $('#panel-template').data('type', 'story');

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
		  nextText: '<img src="/right.png" alt="next">',
		  prevText: '<img src="/left.png" alt="prev">',
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

  		event.preventDefault();

      $(document).bind('click', closeHandler);
    });
	});

	$('#start-selector .selected').bind('click', function(event) {

		var date = $('.main-panel').data('attributes').start;
		var content = $('#start-selector .content');
		content.datepicker('setDate', date);
		content.css('visibility', 'visible');
	});

	$('.ui-datepicker').on('click', function(event) {

		event.preventDefault();
	});

	$('#length-selector .selected').bind('click', function(event) {

		var startDate = $('.main-panel').data('attributes').start;
		var date = new Date(startDate.getTime() + ($('.main-panel').data('attributes').length * MS_DAYS_FACTOR));

		$('#length-selector .content').datepicker('setDate', date);    
		// Ensure there cannot be selected a date before the start.
		$('#length-selector .content').datepicker('option', 'minDate', $('.main-panel').data('attributes').start);
		$('#length-selector .content').css('visibility', 'visible');    
	});


  $('.main-panel').data('socketio_handlers').add = add;
  $('.main-panel').data('socketio_handlers').assign = add;
  $('.panel').each(function() {

  	$(this).data('socketio_handlers').deassign = remove;
  	$(this).data('socketio_handlers').update_remaining_time = requestRemainingTimeCalculation;
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
		color: updateColor,
		remaining_time: updateRemainingTimeCalculation
	});
});
