 $(document).ready(function() {
  
  initPopupSelector($('#story-selector'), 'story_id', function(fillIn) {
    
    var sprint_id = $('#story-selector').data('selected').parent_id;

    $.ajax({

      url: '/story',
      type: 'GET',
      headers: {parent_id: sprint_id},
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        fillIn(data);
        $('#story-selector .content .line').bind('click', $('.main-panel'), function(event) {

          var task = event.data;
          var line = $(event.target);
          var storyId = line.data('id');

          update(task, {story_id: storyId}, function() {

            $('#story-selector .open span').text(line.text());
          });
        });
      },
      error: handleServerError
    });
  });    
    
  var colors = ["yellow", "orange", "red", "purple", "blue", "green"];

  initPopupSelector($('#color-selector'), 'color', function(fillIn) {
    
    fillIn($.map(colors, function(color) {

      return {id: color};
    }));

    $('#color-selector .content .color').each(function(index, value){

      var colorBox = $(value);
      var colorId = colorBox.data('id');
      colorBox.addClass(colorId);
      colorBox.addClass('box-' + index);  
    });

    $('#color-selector .content .color').bind('click', $('.main-panel'), function(event) {

      var task = event.data;

      var chosenColor = $(event.target);
      var colorId = chosenColor.data('id');

      update(task, {color: colorId}, function() {

        colorId = task.data('attributes').color;
        $('.main-panel .header, .main-panel .header input, #color-selector .selected').removeClass(colors.join(' ')).addClass(colorId);
      }); 
    });
  });

  $('input[name="initial_estimation"], input[name="remaining_time"], input[name="time_spent"]').data('parser', function(value) {

    var result = value.match(/^\d{1,2}(\.\d{1,2}){0,1}$/);
    if (result === null) {

      return null;
    }
    result = parseFloat(value);
    if (isNaN(result)) { // should not happen but anyway

      return null;
    }

    return result;
  });
});