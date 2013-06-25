var colors = ["yellow", "orange", "red", "purple", "blue", "green"];

var clientUUID = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {

  var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
  return v.toString(16);
});

var ajaxQueue = [];

function ackAjax(uuid) {

  if (uuid == clientUUID) {

    ajaxQueue.shift();
    if (ajaxQueue.length > 0) {

      ajaxQueue[0]();
    }
  }
}

function queueAjax(ajax) {

  ajaxQueue.push(ajax);
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
    
    var nameAttribute = selector.data('name');

    updatePopup(function(data) {
    
      data.sort(function(a, b) {
      
        if (a[nameAttribute] < b[nameAttribute]) {

          return -1;
        }
        else if(a[nameAttribute] > b[nameAttribute]) {

          return 1;
        }
        else {

          return 0;
        }
      });

      $('.content', selector).children().remove();
      
      data.forEach(function(item) {
      
        var newItem = $('.template', selector).children().clone(true);
        newItem.text(item[nameAttribute]);
        newItem.data('id', item._id);

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

      return {_id: color};
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

      requestUpdate(task, {color: colorId});
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

  queueAjax(function() {

    $.ajax({
    
      url: '/' + type,
      headers: {parent_id: parent_id, client_uuid: clientUUID},
      type: 'PUT',
      error: function(data, textStatus, jqXH) {

        shiftAjaxQueue(); 
        handleServerError(data, textStatus, jqXH);
      }
    });
  });
}

function update(id, type, attributes) {

  var item = $('#' + prefix(id));

  // TODO: what if there is no main-panel?
  var parentType = $('.main-panel').data('type');
  var parentId = $('.main-panel').data('attributes')._id;

  // view contains item
  if (item.length > 0) {

    // assignment change requested?
    if ((attributes[parentType + '_id']) && (attributes[parentType + '_id'] != parentId)) {

      remove(id);
    }
    // assignment is kept.
    else {

      for (var i in attributes) {

        item.data('attributes')[i] = attributes[i];
      }

      // necessary gui updates

      if (attributes.priority) {

        sortPanels();  
      }

      for (i in attributes) {

        $('input[name="' + i + '"], textarea[name="' + i + '"]', item).val(attributes[i]);
      }

      if (attributes.color) {

        $('.header, .header input, #color-selector .selected', item).removeClass(colors.join(' ')).addClass(attributes.color);
      }

      $.each(['story', 'sprint'], function(index, type) {

        if (!attributes[type + '_id']) {

          return;
        }

        var selector = $('#' + type + '-selector');

        if (selector.data('selected').id != attributes[type + '_id']) {

          $.ajax({

            url: '/' + type + '/' + attributes[type + '_id'],
            type: 'GET',
            dataType: 'json',
            success: function(data, textStatus, jqXHR) {

              var label = data[selector.data('name')];
              $('.open span', selector).text(label);
              selector.data('selected', data);
            },
            error: handleServerError
          });
        }
      });
    }
  }
  // item is to be added due to assignment change
  else if (attributes[parentType + '_id'] == parentId) {

    $.ajax({

      url: '/' + type + '/' + id,
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {

        add(type, parentType, data);
      },
      error: handleServerError
    });
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

  queueAjax(function () {

    $.ajax({
      
      url: '/' + type + '/' + id,
      type: 'POST',
      headers: {client_uuid: clientUUID},
      contentType: 'application/json',
      data: JSON.stringify(postData),
      beforeSend: function(jqXHR, settings) {

        jqXHR.setRequestHeader('rev', item.data('attributes')._rev);
      },
      error: function(data, textStatus, jqXH) {

        shiftAjaxQueue();
        if (undo) {

          undo();
        }  
        handleServerError(data, textStatus, jqXH);
      }
    });
  });
}

function remove(id) {

  $('#' + prefix(id)).slideUp(100, function() {      
  
    $('#' + prefix(id)).remove();
  });

  // TODO: handle case when the gui item is the main-panel?
}

function requestRemove(id, type, rev) {

  if (!confirm('Do you want to remove the item and its assigned objects?')) return;

  queueAjax(function() {

    $.ajax({
    
      url: '/' + type + '/' + id,
      type: 'DELETE',
      headers: {client_uuid: clientUUID},
      beforeSend: function(jqXHR, settings) {

        jqXHR.setRequestHeader('rev', $('#uuid-' + id).data('attributes')._rev);
      },
      error: function(data, textStatus, jqXH) {

        shiftAjaxQueue();
        handleServerError(data, textStatus, jqXH);
      }
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

    for (var i in data.ids) {

      remove(data.ids[i]);
    }
    ackAjax(data.source_uuid);
  });

  socket.on('add', function (data) {

    add(data.type, data.parent_type, data.data);
    ackAjax(data.source_uuid);
  });

  socket.on('update', function (data) {

    update(data.id, data.type, data.data);
    ackAjax(data.source_uuid);
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
