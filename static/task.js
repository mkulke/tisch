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
            //selector.data('selected', item);
          });
        });
      },
      error: handleServerError
    });
  });    
         
  initPopupSelector($('#color-selector'), 'color', function(fillIn) {
    
    fillIn([{id: "red"}, {id: "green"}, {id: "yellow"}, {id: "orange"}, {id: "purple"}, {id: "blue"}]);

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
        $('#color-selector .selected').removeClass("red green yellow orange purple blue").addClass(colorId);
        $('.main-panel .header, .main-panel .header input').removeClass("red green yellow orange purple blue").addClass(colorId);
      }); 
    });

    /*$('#color-selector .content .color').bind('click', function(event) {

      var chosenColor = $(event.target);
      var colorId = chosenColor.data('id');
      $('#color-selector .selected').removeClass("red green yellow orange purple blue").addClass(colorId);
      $('.main-panel .header, .main-panel .header input').removeClass("red green yellow orange purple blue").addClass(colorId);
    });*/
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

  /*$('.main-panel').on('click', '.save-button', function(event) {
   
    event.preventDefault();

    var task = $(event.delegateTarget);

    var dbAttributes = task.data('attributes');
    var id = dbAttributes._id;

    var summary = $('input[name="summary"]', task).val();
    var description = $('textarea', task).val();
    var initialEstimation = $('input[name="initial_estimation"]', task).val();
    var remainingTime = $('input[name="remaining_time"]', task).val();
    var timeSpent = $('input[name="time_spent"]', task).val();
    var story = $('#story-selector').data('selected').id;
    var color = $('#color-selector').data('selected').id;

    try {
     
      function isValidNumber(value, name) {
      
        var result = value.match(/^\d{1,2}(\.\d{1,2}){0,1}$/);
        if (!result) {
    
          throw name + ' must be specified as a positive number < 100 with not more than two precision digits (e.g. "1" or "99.25").';
        }
      }
     
      isValidNumber(initialEstimation, "Initial estimation");    
      isValidNumber(remainingTime, "Remaining time");
      isValidNumber(timeSpent, "Time spent");
      
      var webAttributes = {

        summary: summary,
        description: description,
        initial_estimation: parseFloat(initialEstimation, 10),
        remaining_time: parseFloat(remainingTime, 10),
        time_spent: parseFloat(timeSpent, 10),
        story_id: story,
        color: color
      };

      var delta = buildPostDelta(webAttributes, dbAttributes);
    
      var rev = dbAttributes._rev;
      updateItem(id, rev, 'task', delta);
    } catch (e) {
    
      showErrorPanel(e);
    }
  });*/
});