var MS_DAYS_FACTOR = 86400000;

$(document).ready(function() {

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    requestAdd('sprint');
  });

  var updateColor = function(item, color) {

     $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(color);  
  }

  $('#panel-template').data('type', 'task');

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

  var updateStart = function(item, dateString) {

    var date = new Date(dateString);
    item.data('attributes').start = date;
    $('.header .start', item).html((date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2));
    var length = item.data('attributes').length;
    var endDate = new Date(date.getTime() + (length * MS_DAYS_FACTOR));
    $('.header .end', item).html((endDate.getMonth() + 1) + '/' + endDate.getDate() + '/' + endDate.getFullYear().toString().substr(2));

  }

  var updateLength = function(item, length) {

    item.data('attributes').length = length;

    var startDate = item.data('attributes').start;
    var date = new Date(startDate.getTime() + (length * MS_DAYS_FACTOR));

    $('.header .end', item).html((date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2));
  }

	$('.panel').data('update', {

		title: updateTitle,
		description: updateDescription,
    start: updateStart,
    length: updateLength,
    color: updateColor
	});
});
