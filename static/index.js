var updateColor = function(item, color) {

  $('.stripe', item).removeClass(COLORS.join(' ')).addClass(color);  
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

var updateStart = function(item, dateString) {

  var date = new Date(dateString);
  item.data('attributes').start = date;
  $('.header .start', item).html((date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2));
  var length = item.data('attributes').length;
  var endDate = new Date(date.getTime() + (length * MS_DAYS_FACTOR));
  $('.header .end', item).html((endDate.getMonth() + 1) + '/' + endDate.getDate() + '/' + endDate.getFullYear().toString().substr(2));
  sortPanels();
}

var updateLength = function(item, length) {

  item.data('attributes').length = length;

  var startDate = item.data('attributes').start;
  var date = new Date(startDate.getTime() + (length * MS_DAYS_FACTOR));

  $('.header .end', item).html((date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear().toString().substr(2));
}

$(document).ready(function() {

  var body = $('body');
  body.data('attributes', {_id: 'index'});
  body.data('type', '');
  body.data('socketio_handlers', {add: add});
  body.data('socketio_handlers').assign = add;
  $('.panel').data('socketio_handlers').deassign = remove;

  $('#add-button').on('click', function(event) {
   
    event.preventDefault();
   
    requestAdd(body);
  });

  $('#panel-template').data('type', 'sprint');

  $('#panel-container').data('sort', function(a, b) {

    return $(a).data('attributes').start - $(b).data('attributes').start;    
  });

	$('.panel').data('update', {

		title: updateTitle,
		description: updateDescription,
    start: updateStart,
    length: updateLength,
    color: updateColor
	});
});
