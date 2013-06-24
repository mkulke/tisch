var colors = ["yellow", "orange", "red", "purple", "blue", "green"];

var ajaxQueue = [];

function shiftAjaxQueue() {

  ajaxQueue.shift();
  if (ajaxQueue.length > 0) {

    ajaxQueue[0]();
  }  
}

function pushAjaxQueue(ajaxCall) {

  ajaxQueue.push(ajaxCall);
  if (ajaxQueue.length == 1) {

    ajaxQueue[0]();
  }  
}

function prefix(id) {

  return 'uuid-' + id;
}

function unPrefix(prefixedId) {

  return prefixedId.substr('uuid-'.length);
}

function attachAttributesToItems(map) {

  for (var type in map) {

    items = map[type];
    items.forEach(function(attributes) {
    
      $('#uuid-' + attributes._id).data('attributes', attributes);
      $('#uuid-' + attributes._id).data('type', type);
    });
  }
}

function initPopupSelector(selector, name, updatePopup) {
  
  var id = selector.attr('id');
    
  // position popup, TODO: adjust the arrow pointing according to css
  var left = $('.open', selector).offset().left - 17;
  var offset = $('a > .content', selector).offset();
  offset.left = left;
  $('a > .content', selector).offset(offset);
        
  var closeHandler = function(event) {

    if (!$(event.target).parents('#' + id + '.popup-selector').length) {    
  
      $('.content', selector).css("visibility", "hidden");
      $(document).unbind('click', closeHandler);
    }
  };  
           
  $('a.open .selected', selector).bind('click', function(event) {

    event.preventDefault();
    
    updatePopup(function(data) {
    
      data.sort(function(a, b) {
      
        if (a.label < b.label) {

          return -1;
        }
        else if(a.label > b.label) {

          return 1;
        }
        else {

          return 0;
        }
      });

      $('.content', selector).children().remove();
      
      data.forEach(function(item) {
      
        var newItem = $('.template', selector).children().clone(true);
        newItem.text(item.label);
        newItem.data('id', item.id);

        $('.content', selector).append(newItem);
        newItem.bind('click', function(event) {
        
          event.preventDefault();

          $('.content', selector).css('visibility', 'hidden');
          $(document).unbind('click', closeHandler);
        });
      });
      
      $(document).bind('click', closeHandler);
  
      $('.content', selector).css('visibility', 'visible');
    });
  });  
}

function initColorSelector() {

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

      requestUpdate(task, {color: colorId});/* , function() {

        colorId = task.data('attributes').color;
        $('.main-panel .header, .main-panel .header input, #color-selector .selected').removeClass(colors.join(' ')).addClass(colorId);
      });*/ 
    });
  });
}

function timeParser(value) {

    var result = value.match(/^\d{1,2}(\.\d{1,2}){0,1}$/);
    if (result === null) {

      return null;
    }
    result = parseFloat(value);
    if (isNaN(result)) { // should not happen but anyway

      return null;
    }

    return result;
  }

function showErrorPanel(message) {

  $('#error-panel .message').text(message);
  $('#error-panel').slideDown(100);
  $("html, body").animate({scrollTop: $('#error-panel').offset().top}, "fast");
}

function handleServerError(qHXR, textStatus, errorThrown) {

  var errorMessage;
  switch(textStatus) {

    case 'timeout':
    
      errorMessage = 'Operation timed out. Possible reasons include network and server issues.';
      break;
    case 'error':
    
      errorMessage = 'Operation failed. ' + errorThrown;
      break;
    default:
    
      errorMessage = 'Operation failed for unknown reasons. Check server logs.';
  }

  shiftAjaxQueue();

  showErrorPanel(errorMessage);
}

function sortPanels() {

  var panels = $('#panel-container li');
  panels.sort(function(a, b) {

    return $(a).data('attributes').priority - $(b).data('attributes').priority;
  });

  $.each(panels, function(index, panel) {

    $('#panel-container').append(panel);
  });
}

function add(type, parentType, data) {

  // TODO: what if no main-panel is present?
  var parentId = $('.main-panel').data('attributes')._id;
  if (data[parentType + '_id'] != parentId) {

    return;
  }

  var newPanel = $('#panel-template').clone(true);

  newPanel.data('type', type);
  newPanel.data('attributes', data);

  newPanel.attr('id', prefix(data._id));     
  
  $('#panel-container').append(newPanel);
  sortPanels();    

  var id = prefix(data._id);
  var input = $('#' + id + " input");
  var attribute = input.attr('name');
  var value = data[attribute];
  input.val(value);
  input.attr('value', value);
  input.addClass(data.color);
  $('.header', newPanel).addClass(data.color);

  var textarea = $('#' + id + " textarea");
  attribute = textarea.attr('name');
  textarea.val(data[attribute]);
  
  $("html, body").animate({ scrollTop: $(document).height() }, "slow");  
}

function requestAdd(type, parent_id) {

  pushAjaxQueue(function() {

    $.ajax({
    
      url: '/' + type,
      headers: {parent_id: parent_id},
      type: 'PUT',
      error: handleServerError
    });
  });
}

function update(id, type, attributes) {

  var item = $('#' + prefix(id));
  var parentType = $('.main-panel').data('type');
  var parentId = $('.main-panel').data('attributes')._id;

  // view contains item or is to be added to the view?
  if (item.length > 0) {

    // item is child of another main-panel and its assignment changed?

    if (($('#panel-container').has(item).length > 0 ) && (attributes[parentType + '_id'] != parentId)) {

      remove(attributes._id);
    }
    else {

      for (var i in attributes) {

        item.data('attributes')[i] = attributes[i];
      }
      //item.data('attributes', attributes);

      // necessary gui updates

      if (attributes.priority) {

        sortPanels();  
      }

      for (var i in attributes) {

        $('input[name="' + i + '"], textarea[name="' + i + '"]', item).val(attributes[i]);
      }

      if (attributes.color) {

        $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(attributes.color);
      }

      $.each(['story', 'sprint'], function(index, type) {

        var selector = $('#' + type + '-selector');

        if (selector.length < 1) {

          return;
        }

        if (selector.data('selected').id != attributes[type + '_id']) {

          $.ajax({

            url: '/' + type + '/' + attributes[type + '_id'],
            type: 'GET',
            dataType: 'json',
            success: function(data, textStatus, jqXHR) {

              $('.open span', selector).text(data.label);
              selector.data('selected', data);
            },
            error: handleServerError
          });
        }
      });
    }
  }
  else if (attributes[parentType + '_id'] == parentId) {

    add(type, attributes);
  }
}

function requestUpdate(item, postData, undo) {

  var attributes = item.data('attributes');

  var skip = true;
  for (var attribute in postData) {

    skip &= (postData[attribute] == attributes[attribute]);
  }

  if (skip) {

    return;
  }

  var id = attributes._id;
  var rev = attributes._rev;
  var type = item.data('type');

  pushAjaxQueue(function () {

    $.ajax({
      
      url: '/' + type + '/' + id,
      type: 'POST',
      contentType: 'application/json',
      data: JSON.stringify(postData),
      beforeSend: function(jqXHR, settings) {

        jqXHR.setRequestHeader('rev', item.data('attributes')._rev);
      },
      error: function(data, textStatus, jqXH) {

        if (undo) {

          undo();
        }    
        handleServerError(data, textStatus, jqXH);
      }
    });
  });

  /*$.ajaxq('client', {
    
    url: '/' + type + '/' + id,
    type: 'POST',
    contentType: 'application/json',
    data: JSON.stringify(postData),
    dataType: 'json', 
    beforeSend: function(jqXHR, settings) {

      jqXHR.setRequestHeader('rev', item.data('attributes')._rev);
    },
    success: function(data, textStatus, jqXH) {

      //item.data('attributes')._rev = data;
      update(data.id, data.type, data.data); 
    },
    error: function(data, textStatus, jqXH) {

      if (undo) {

        undo();
      }    
      handleServerError(data, textStatus, jqXH);
    }
  });*/
}

function remove(id) {

  $('#' + prefix(id)).slideUp(100, function() {      
  
    $('#' + prefix(id)).remove();
  });

  // TODO: handle case when the gui item is the main-panel, furthermore: what to do you are working on a child panel, which was
  // deleted by cascade?
}

function requestRemove(id, type, rev) {

  if (!confirm('Do you want to remove the item and its assigned objects?')) return;

  pushAjaxQueue(function() {

    $.ajax({
    
      url: '/' + type + '/' + id,
      type: 'DELETE',
      beforeSend: function(jqXHR, settings) {

        jqXHR.setRequestHeader('rev', $('#uuid-' + id).data('attributes')._rev);
      },
      error: handleServerError
    });
  });
}

function updatePriority(li, previousLi, nextLi) {

  var previousPriority = 0;
  var nextPriority = 0;
  var priority = 0;
  
  // not the first item
  if (li.index() > 0) {
  
    previousPriority = previousLi.data('attributes').priority;
  }
  
  // last item
  if(li.index() + 1 == $('#panel-container li').size()) {
  
    priority = Math.ceil(previousPriority + 1);
  }
  else {
  
    nextPriority = nextLi.data('attributes').priority;
    priority = (nextPriority - previousPriority) / 2 + previousPriority;
  }
  
  requestUpdate(li, {priority: priority}, sortPanels);
}

$(document).ready(function() {

  var socket = io.connect('http://localhost');

  socket.on('remove', function (data) {

    remove(data.id);
    shiftAjaxQueue();
  });

  socket.on('add', function (data) {

    add(data.type, data.parent_type, data.data);
    shiftAjaxQueue();
  });

  socket.on('update', function (data) {

    update(data.id, data.type, data.data);
    shiftAjaxQueue();
  });

  // This enables drag and drop on the list items
  $("#panel-container").sortable({
  
    tolerance: 'pointer',
    containment: '#panel-container'
  });

  // This prevents firefox from keeping form values after reload.
  $('input,textarea').attr('autocomplete', 'off');

  $('.panel').on('click', '.remove-button', function(event) {
  
    event.preventDefault();
  
    var item = $(event.delegateTarget);
    var dbAttributes = item.data('attributes');
    var id = dbAttributes._id;
    var rev = dbAttributes._rev;
    var type = item.data('type');

    requestRemove(id, type, rev);
  });

  $('.panel').on('click', '.hide-button', function(event) {

    event.preventDefault();

    var story = $(event.delegateTarget);
    $('.description', story).slideUp(100, function() {
    
      $('.hide-button', story).hide();
      $('.show-button', story).show();
    });
  });
    
  $('.panel').on('click', '.show-button', function(event) {

    event.preventDefault();

    var item = $(event.delegateTarget);
    $('.description', item).slideDown(100, function() {
    
      $('.show-button', item).hide();
      $('.hide-button', item).show();
    });
  });
        
  $('#error-panel').on('click', '.ok-button', function(event) {

    event.preventDefault();

    $('#error-panel').slideUp(100);
  });
  
  $('.panel, .main-panel').on('click', '.description .string', function(event) {

    var string = $(event.target);
    string.hide();
    var panel = $(event.delegateTarget);
    var textarea = $('#' + panel.attr('id') + ' .description textarea');
    
    // hack to put cursor to end.
    
    var data = string.html();
    textarea.show().focus().val('').val(data);   
  });
  
  $('#panel-container').on('sortstop', function(event, ui) {
  
    var li = ui.item;
    var previousLi = ui.item.prev();
    var nextLi = ui.item.next();
  
    updatePriority(li, previousLi, nextLi);
  });

  $('.panel .handle').on('dblclick', function(event) {
  
    var handle = $(event.delegateTarget);
    var li = handle.parents('li').first();
    var id = li.data('attributes')._id;
    var type = li.data('type');

    window.location.href = '/' + type + '/' + id;
  });

  $('input, textarea').data('timer', null);

  $('.panel, .main-panel').on('keyup', ['input', 'textarea'], function(event) {

    if((event.target.localName == 'input') && (event.which == 13)) {
    
      event.preventDefault();
      return false;
    }  

    var field = $(event.target);
    var attribute = field.attr('name');
    var item = $(event.delegateTarget);
    var value = field.val(); 
    
    clearTimeout(field.data('timer'));
    field.data('timer', setTimeout(function() { 

      var parseValue = field.data('parser');
      if (parseValue) {

        value = parseValue(value);
        if (value === null) {

          field.siblings('.error-popup').find('.content').show();
          return false;
        }
        field.siblings('.error-popup').find('.content').hide();
      }

      var data = {};
      data[attribute] = value;

      requestUpdate(item, data, function() {

        field.val(item.data('attributes')[attribute]);  
      });
    }, 1500));
  });
});

// this makes safari reload a page when using the back button.

window.onpageshow = function(event) {
    if (event.persisted) {

        window.location.reload();
    }
};
