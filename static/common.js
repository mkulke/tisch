var COLORS = ["yellow", "orange", "red", "purple", "blue", "green"];
var MS_DAYS_FACTOR = 86400000;
var AUTOGROW_COMFORT_ZONE = 5;

var clientUUID = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {

  var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
  return v.toString(16);
});

function prefix(id) {

  return 'uuid-' + id;
}

function unPrefix(prefixedId) {

  return prefixedId.substr('uuid-'.length);
}

function isUpdateOk(item, text) {

  return ((item.data('timer') === null) && (item.val() != text))
}

function attachAttributesToItems(map) {

  // to please jshint 'function within a loop'

  function makeSetter(type) {

    return function(attributes) {

      $('#uuid-' + attributes._id).data('attributes', attributes);
      $('#uuid-' + attributes._id).data('type', type);
    };
  }

  for (var type in map) {

    items = map[type];
    items.forEach(makeSetter(type));
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
    
    fillIn($.map(COLORS, function(color) {

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

      requestUpdate(task, 'color', colorId);
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
    
      errorMessage = 'Operation failed: ' + ((errorThrown != '') ? errorThrown : 'Unknown server error.');
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

function add(parent_id, attributes) {

  if ($('.main-panel').data('attributes')._id != parent_id) {

    // does not concern this view.
    return;
  }

  var newPanel = $('#panel-template').clone(true);

  newPanel.data('attributes', attributes);

  newPanel.attr('id', prefix(attributes._id));

  for (var key in attributes) {

    if (newPanel.data('update')[key]) {

      newPanel.data('update')[key](newPanel, attributes[key]);      
    }
  }

  $('#panel-container').append(newPanel);
  sortPanels();    

  $('.header', newPanel).addClass(attributes.color);
  // hack: it seems the autogrow stuff is not correctly cloned, 
  // hence we need to re-add it here.
  $('.header input', newPanel).autoGrow({comfortZone: AUTOGROW_COMFORT_ZONE});

  $("html, body").animate({ scrollTop: $(document).height() }, "slow");  
}

function requestAdd(type, parent_id) {

  var headers = {client_uuid: clientUUID};
  if (parent_id) {

    headers.parent_id = parent_id;
  }

  $.ajaxq('client', {
  
    url: '/' + type,
    headers: headers,
    type: 'PUT',
    success: function(data, textStatus, jqXHR) {

      add(data.parent_id, data.attributes);
    },
    error: function(data, textStatus, jqXHR) {

      handleServerError(data, textStatus, jqXHR);
    }
  });
}

function update(id, rev, key, value) {

  var item = $('#' + prefix(id));
  var mainPanel = $('.main-panel');
  var parentType = mainPanel.length > 0 ? mainPanel.data('type') : null;
  var parentId = mainPanel.length > 0 ? mainPanel.data('attributes')._id : null;

  // item not present?
  if (item.length != 1) {

    // assignment changed to main item?
    if ((key == parentType + '_id') && (value == parentId)) {

      var type = $('#panel-template').data('type'); 
      $.ajaxq('client', {

        url: '/' + type + '/' + id,
        type: 'GET',
        dataType: 'json',
        success: function(data, textStatus, jqXHR) {

          add(parentId, data);
        },
        error: handleServerError
      });  
    }
  }
  // item present
  else {

    // assignment removed from main item?
    if ((key == parentType + '_id') && (value != parentId)) {

      remove(id);  
    }
    else {

      item.data('attributes')._rev = rev;
      item.data('attributes')[key] = value;
      if (item.data('update')[key]) {

        item.data('update')[key](item, value);
      }
    }
  }
}

function updateCalculation(id, key, value) {

  var item = $('#' + prefix(id));

  if (item.length == 1) {

    if (item.data('update')[key]) {

      item.data('update')[key](item, value);
    }
  }
}

function requestUpdate(item, key, value, undo) {

  var attributes = item.data('attributes');

  if (attributes[key] == value) {

    // no change. skip.
    return;
  }

  var id = attributes._id;
  var rev = attributes._rev;
  var type = item.data('type');

  $.ajaxq('client', {
    
    url: '/' + type + '/' + id,
    type: 'POST',
    headers: {client_uuid: clientUUID},
    contentType: 'application/json',
    data: JSON.stringify({key: key, value: value}),
    beforeSend: function(jqXHR, settings) {

      jqXHR.setRequestHeader('rev', item.data('attributes')._rev);
    },
    success: function(data, textStatus, jqXHR) {

      update(data.id, data.rev, data.key, data.value);
    },
    error: function(data, textStatus, jqXHR) {

      if (undo) {

        undo();
      }  
      handleServerError(data, textStatus, jqXHR);
    }
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

  $.ajaxq('client', {
  
    url: '/' + type + '/' + id,
    type: 'DELETE',
    headers: {client_uuid: clientUUID},
    beforeSend: function(jqXHR, settings) {

      jqXHR.setRequestHeader('rev', $('#uuid-' + id).data('attributes')._rev);
    },
    success: function(ids, textStatus, jqXHR) {

      for (var i in ids) {

        remove(ids[i]);
      }
    },
    error: function(data, textStatus, jqXHR) {

      handleServerError(data, textStatus, jqXHR);
    }
  });
}

$(document).ready(function() {

  var socket = io.connect('http://localhost'); 

  socket.on('connect', function() {

    socket.emit('register', {

      client_uuid: clientUUID
    });    
  });

  socket.on('remove', function (ids) {

    for (var i in ids) {

      remove(ids[i]);
    }
  });

  socket.on('add', function (data) {

    add(data.parent_id, data.attributes);
  });

  socket.on('update', function (data) {

    update(data.id, data.rev, data.key, data.value);
  });

  socket.on('update_calculation', function (data) {

    updateCalculation(data.id, data.key, data.value);
  });

  // This makes the header input grow automatically with its value.
  $('.header input').autoGrow({comfortZone: AUTOGROW_COMFORT_ZONE});
  $('.header input').css('min-width', '0px');

  // This enables drag and drop on the list items
  $("ul#panel-container").sortable({
  
    tolerance: 'pointer',
    containment: '#panel-container'
  });

  // This prevents firefox from keeping form values after reload.
  $('input,textarea').attr('autocomplete', 'off');

  $('.panel').on('click', '.remove.button', function(event) {
  
    event.preventDefault();
  
    var item = $(event.delegateTarget);
    var dbAttributes = item.data('attributes');
    var id = dbAttributes._id;
    var rev = dbAttributes._rev;
    var type = item.data('type');

    requestRemove(id, type, rev);
  });

  $('.panel').on('click', '.hide.button', function(event) {

    event.preventDefault();

    var item = $(event.delegateTarget);
    $('.body', item).slideUp(100, function() {
    
      $('.hide.button', item).hide();
      $('.show.button', item).show();
    });
  });
    
  $('.panel').on('click', '.show.button', function(event) {

    event.preventDefault();

    var item = $(event.delegateTarget);
    $('.body', item).slideDown(100, function() {
    
      $('.show.button', item).hide();
      $('.hide.button', item).show();
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
    
    requestUpdate(li, 'priority', priority, sortPanels);
  });

  $('.panel').each(function(index, element) {

    var panel = $(element);
    var header = $('.header', panel);

    panel.on('dblclick', '.header', function(event) {
  
      var panel = $(event.delegateTarget);
      var id = panel.data('attributes')._id;
      var type = panel.data('type');
      window.location.href = '/' + type + '/' + id;
    });

    $('.button, input', header).on('dblclick', function(event) {
      
      return false;
    });
  });

  $('input, textarea').data('timer', null);

  $('.panel, .main-panel').on('keyup', ['input', 'textarea'], function(event) {

    if((event.target.localName == 'input') && (event.which == 13)) {
    
      event.preventDefault();
      return false;
    }  

    var field = $(event.target);
    var key = field.attr('name');
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

      requestUpdate(item, key, value, function() {

        field.val(item.data('attributes')[key]);  
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
