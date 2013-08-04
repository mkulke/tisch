var updateTitle = function(item, text) {

	var input = $('input[name="title"]', item);
	if (isUpdateOk(input, text)) {

		input.val(text);
		input.trigger('input.autogrow');
	}
}

var updateSprintId = function(item, id) {

  var selector = $('#sprint-selector', item);

  $.ajaxq('client', {

    url: '/sprint/' + id,
    type: 'GET',
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {

      var label = data[selector.data('name')];
      $('span.selected', selector).text(label);
      $('span.selected', selector).attr('id', prefix(data._id));
      selector.data('selected', data);
    },
    error: handleServerError
  });
};

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
		input.trigger('input.autogrow');
	}
}

var updateRemainingTime = function(item, remainingTime) {

	var span = $('span.remaining.text', item);
	span.html(remainingTime);
	if (remainingTime == 0) {

	  $('.done', item).show();
	  $('.remaining', item).hide();
	}
	else {

	  $('.done', item).hide();
	  $('.remaining', item).show();	
	}
}

var updateColor = function(item, color) {

	$('.stripe, #color-selector .selected', item).removeClass(COLORS.join(' ')).addClass(color);  
}

$(document).ready(function() {

  $('#sprint-selector').data('name', 'title');    
  initPopupSelector($('#sprint-selector'), 'sprint_id', function(fillIn) {

    $.ajax({

      url: '/sprint',
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        fillIn(data);
        $('#sprint-selector .content .line').bind('click', $('.main-panel'), function(event) {

          var story = event.data;
          var line = $(event.target);
          var sprintId = line.data('id');

          requestUpdate(story, 'sprint_id', sprintId);
        });
      },
      error: handleServerError
    });
  });    

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    requestAdd_test($('.main-panel'));
  });

  $('#panel-template').data('type', 'task');

  $('#panel-container').data('sort', function (a, b) {

    return $(a).data('attributes').priority - $(b).data('attributes').priority;  
  });

  $('input[name="estimation"]').data('parser', timeParser);

  initColorSelector();
  
  $('.main-panel').data('socketio_handlers').add = add_test;
  $('.main-panel').data('socketio_handlers').assign = add_test;
  $('.panel').data('socketio_handlers').deassign = remove;

    // make sure story title changes are reflected in the view.
  $('#sprint-selector span.selected').data('socketio_handlers', { update: function(data) { 

    if (data.key == 'title') {

      $('#sprint-selector span.selected').text(data.value);     
    }
  }});

	$('.main-panel').data('update', {

		title: updateTitle,
		description: updateDescription,
		estimation: updateEstimation,
		color: updateColor,
		sprint_id: updateSprintId
	});

	$('.panel').data('update', {

		summary: updateSummary,
		description: updateDescription,
		priority: updatePriority,
		color: updateColor,
		remaining_time: updateRemainingTime
	});
});
