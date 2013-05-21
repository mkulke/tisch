var itemMap = {};

function prefix(id) {

  return 'uuid-' + id;
}

function unPrefix(prefixedId) {

  return prefixedId.substr('uuid-'.length);
}

function populateItemMap(items) {

  $.each(items, function(i, item) {
  
    itemMap[item._id] = item;
  });
}

function showErrorPanel(qHXR, textStatus, errorThrown) {

  switch(textStatus) {

    case 'timeout':
    
      var errorMessage = 'Operation timed out. Possible reasons include network and server issues.';
      break;
    case 'error':
    
      var errorMessage = 'Operation failed. ' + errorThrown;
      break;
    default:
    
      var errorMessage = 'Operation failed for unknown reasons. Check server logs.';
  }
  $('#error-panel #message').text(errorMessage);
  $('#error-panel').slideDown(100);
}

function addItem(type, parent_id) {

  $.ajax({
  
    url: '/' + type,
    headers: {parent_id: parent_id},
    type: 'PUT',
    dataType: 'json',
    success: function(data, textStatus, jqXHR) {
    
      itemMap[data._id] = data;
    
      var newPanel = $('#panel-template').clone(true)
      newPanel.attr('id', prefix(data._id));     
    
      // re-sort panels, the new item might not alway be of the lowest prio.
      var panels = $('#panel-container li').detach();
      panels = panels.add(newPanel);
      panels.sort(function(a, b) {
      
        return itemMap[unPrefix(a.id)].priority - itemMap[unPrefix(b.id)].priority;
      });
      
      $('#panel-container').append(panels);
          
      var id = prefix(data._id);
      var input = $('#' + id + " input");
      var attribute = input.attr('name');
      input.val(data[attribute]);
    
      var textarea = $('#' + id + " textarea");
      attribute = textarea.attr('name');
      textarea.val(data[attribute]);
      
      $("html, body").animate({ scrollTop: $(document).height() }, "slow");
    },
    error: showErrorPanel
  });
}

function removeItem(id, type, post_data) {

  if (confirm('Do you want to remove the item and its assigned objects?') == false) return;

  $.ajax({
  
    url: '/' + type + '/' + id,
    type: 'DELETE',
    data: post_data,
    success: function(data, textStatus, jqXHR) {
    
      delete itemMap[id];
      $('#' + prefix(id)).slideUp(100, function() {      
      
        $('#' + prefix(id)).remove();
      });
    },
    error: showErrorPanel
  });
}

function updateItem(id, type, post_data) {

  $.ajax({
    
    url: '/' + type + '/' + id,
    type: 'POST',
    dataType: 'json',
    data: post_data,
    success: function(data, textStatus, jqXHR) {
  
      itemMap[id] = data;
      $('#' + prefix(id) + ' .save-button').hide();
    },
    error: showErrorPanel
  });
}

/*function invalidateBackCache() {

  // necessary for Safari: mobile & desktop
}

window.addEventListener("unload", invalidateBackCache, false);*/

$(document).ready(function() {

  // This enables drag and drop on the list items
  $("#panel-container").sortable({
  
    tolerance: 'pointer',
    containment: '#panel-container'
  });

  // This prevents firefox from keeping form values after reload.
  $('input,textarea').attr('autocomplete', 'off');

  $('.panel').on('click', '.hide-button', function(event) {

    var story = $(event.delegateTarget);
    $('.description', story).slideUp(100, function() {
    
      $('.hide-button', story).hide();
      $('.show-button', story).show();
    });
  });
  
  $('#add-button').on('click', function(event) {
   
    var mainPanel = $('.main-panel').first();
    var id = unPrefix(mainPanel.attr('id'));
    addItem(types.child, id);
  });
  
  $('.panel').on('click', '.show-button', function(event) {

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
    var id = unPrefix(item.attr('id'));
    
    if (itemMap[id][attribute] != field.val()) {
    
      $('.save-button', item).show();
    }
  });
        
  $('#error-panel').on('click', '.ok-button', function(event) {

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
  
    var item = ui.item;
    var previousPriority = 0;
    var nextPriority = 0;
    var priority = 0;
    
    if (item.index() > 0) {
    
      var previousId = unPrefix(ui.item.prev().attr('id'));
      previousPriority = itemMap[previousId].priority;
    }
    
    // last item
    if(item.index() + 1 == $('#panel-container li').size()) {
    
      priority = previousPriority + 1;
    }
    else {
    
      var nextId = unPrefix(ui.item.next().attr('id'));
      nextPriority = itemMap[nextId].priority;
      priority = (nextPriority - previousPriority) / 2 + previousPriority;
    }
    
    var id = unPrefix(ui.item.attr('id'));
    itemMap[id].priority = priority;
    
    $('.save-button', item).show();
  });
  
  $('.panel').on('click', '.remove-button', function(event) {
  
    var story = $(event.delegateTarget);
    var id = unPrefix(story.attr('id'));
    var post_data = itemMap[id];
    
    removeItem(id, types.child, post_data);
  });
  
  $('.panel .handle').on('dblclick', function(event) {
  
    var handle = $(event.delegateTarget);
    var li = handle.parents('li').first();
    var id = unPrefix(li.attr('id'));
    window.location.href = '/' + types.child + '/' + id;
  });
});