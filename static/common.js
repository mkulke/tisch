$(document).ready(function() {

  // This enables drag and drop on the list items
  $("#panel-container").sortable({
  
    containment: '#panel-container'
  });
  $("#panel-container").disableSelection();

  // This prevents firefox from keeping form values after reload.
  $('input,textarea').attr('autocomplete', 'off');

  $('.panel').on('click', '.hide-button', function(event) {

    var story = $(event.delegateTarget);
    $('.description', story).slideUp(100, function() {
    
      $('.hide-button', story).hide();
      $('.show-button', story).show();
    });
  });
  
  $('.panel').on('click', '.show-button', function(event) {

    var story = $(event.delegateTarget);
    $('.description', story).slideDown(100, function() {
    
      $('.show-button', story).hide();
      $('.hide-button', story).show();
    });
  });
  
  $('.panel').on('keyup', ['input', 'textarea'], function(event) {

    if((event.target.localName == 'input') && (event.which == 13)) {
    
      event.preventDefault();
      return false;
    }
    var story = $(event.delegateTarget);
    $('.save-button', story).show();
  });
  
  // prevent submit form action when pressing return in textfields
    
  $('.panel').on('keypress', 'input', function(event) {
  
    if(event.which == 13) {
    
      event.preventDefault();
      return false;
    }
  });
  
  $('#error-panel').on('click', '.ok-button', function(event) {

    $('#error-panel').slideUp(100);
  });
});