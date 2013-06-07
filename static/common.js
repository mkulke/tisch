function prefix(id) {

  return 'uuid-' + id;
}

function unPrefix(prefixedId) {

  return prefixedId.substr('uuid-'.length);
}

function attachAttributesToItems(map) {

  for (type in map) {

    items = map[type];
    items.forEach(function(attributes) {

      // this attribute is an exception b/c the prio can't be
      // extracted from the html alone (like input values), so 
      // the client prio is stored in an extra variable. 
      $('#uuid-' + attributes._id).data('priority', attributes.priority);      
      $('#uuid-' + attributes._id).data('attributes', attributes);
      $('#uuid-' + attributes._id).data('type', type);
    });  
  }
}

function buildPostDelta(webAttributes, dbAttributes) {

  var delta = {};

  for (var index in webAttributes) {

    var value = webAttributes[index];
    if (dbAttributes[index] != value) {

      delta[index] = value;
    }       
  }

  return delta;
}

function initPopupSelector(selector, name, updatePopup) {
  
  //var selector = $(this);
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
           
  $('a.open span', selector).bind('click', function(event) {

    event.preventDefault();
    
    updatePopup(function(data) {
    
      $('.content', selector).children().remove();
      
      data.forEach(function(item) {
      
        var newItem = $('.template', selector).children().clone(true);
        newItem.text(item.label);

        $('.content', selector).append(newItem);
        newItem.bind('click', function(event) {
        
          event.preventDefault();
        
          $('.open span', selector).text(item.label);
          selector.data('selected', item.id);

          var mainAttributes = $('.main-panel').data('attributes');
          if(mainAttributes[name] != item.id) {

            $('.main-panel .save-button').show();
          }

          $('.content', selector).css("visibility", "hidden");
          $(document).unbind('click', closeHandler);
        });
      });
      
      $(document).bind('click', closeHandler);
  
      $('.content', selector).css("visibility", "visible");
    });
  });  
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

function addItem(type, parent_id) {

  $.ajax({
  
    url: '/' + type,
    headers: {parent_id: parent_id},
    type: 'PUT',
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {
    
      var newPanel = $('#panel-template').clone(true);
    
      newPanel.data('type', type);
      newPanel.data('attributes', data);
      newPanel.data('priority', data.priority);

      newPanel.attr('id', prefix(data._id));     
    
      // re-sort panels, the new item might not alway be of the lowest prio.
      var panels = $('#panel-container li').detach();
      panels = panels.add(newPanel);
      panels.sort(function(a, b) {
      
        return $(a).data('priority') - $(b).data('priority');
      });
      
      $('#panel-container').append(panels);
          
      var id = prefix(data._id);
      var input = $('#' + id + " input");
      var attribute = input.attr('name');
      var value = data[attribute];
      input.val(value);
      input.attr('value', value);
    
      var textarea = $('#' + id + " textarea");
      attribute = textarea.attr('name');
      textarea.val(data[attribute]);
      
      $("html, body").animate({ scrollTop: $(document).height() }, "slow");
    },
    error: handleServerError
  });
}

function removeItem(id, type, rev) {

  if (!confirm('Do you want to remove the item and its assigned objects?')) return;

  $.ajax({
  
    url: '/' + type + '/' + id,
    type: 'DELETE',
    headers: {rev: rev},
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {
    
      $('#' + prefix(id)).slideUp(100, function() {      
      
        $('#' + prefix(id)).remove();
      });
    },
    error: handleServerError
  });
}

function updateItem(id, rev, type, post_data) {

  $.ajax({
    
    url: '/' + type + '/' + id,
    type: 'POST',
    headers: {rev: rev},
    dataType: 'json',
    contentType: 'application/json',
    data: JSON.stringify(post_data),
    success: function(data, textStatus, jqXHR) {
  
      $('#' + prefix(id)).data('attributes', data);
      $('#' + prefix(id) + ' .save-button').hide();
    },
    error: handleServerError
  });
}

function updatePriority(li, previousLi, nextLi) {

  var previousPriority = 0;
  var nextPriority = 0;
  var priority = 0;
  
  // not the first item
  if (li.index() > 0) {
  
    previousPriority = previousLi.data('priority');
  }
  
  // last item
  if(li.index() + 1 == $('#panel-container li').size()) {
  
    priority = previousPriority + 1;
  }
  else {
  
    nextPriority = nextLi.data('priority');
    priority = (nextPriority - previousPriority) / 2 + previousPriority;
  }
  
  li.data('priority', priority);

  $('.save-button', li).show();
}

$(document).ready(function() {

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

    removeItem(id, type, rev);
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
  
  $('.panel, .main-panel').on('keyup', ['input', 'textarea'], function(event) {

    if((event.target.localName == 'input') && (event.which == 13)) {
    
      event.preventDefault();
      return false;
    }
    var field = $(event.target);
    var attribute = field.attr('name');
    var item = $(event.delegateTarget);
    
    if (item.data('attributes')[attribute] != field.val()) {

      $('.save-button', item).show();
    }
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
});