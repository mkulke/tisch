common = (->

  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  constants =

    en_US:

      ADD_TASK: 'Add Task'
      COLOR: 'Color'
      ESTIMATION: 'Estimation'
      INITIAL_ESTIMATION: 'Initial estimation'
      OK: 'Ok'
      OPEN: 'Open'
      REMAINING_TIME: 'Remaining time'
      REMOVE: 'Remove'
      SPRINT: 'Sprint'
      STORY: 'Story'
      TIME_SPENT: 'Time spent'
      TODAY: 'today'
      VALID_TIME_MESSAGE: 'This attribute has to be specified as a positive number < 100 with two or less precision digits (e.g. "1" or "99.25").'
  {
    COLORS: ['yellow', 'orange', 'red', 'purple', 'blue', 'green']
    uuid: uuid
    constants: constants
    MS_TO_DAYS_FACTOR: 86400000
    KEYUP_UPDATE_DELAY: 1500
    DATE_DISPLAY_FORMAT: 'mm/dd/yy'
  }
)()

class SocketIO

  constructor: (@view, @model) ->

    socket = io.connect "http://#{window.location.hostname}"
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', @messageHandler    
  messageHandler: ->

class View

  constructor: (ractiveTemplate, ractiveHandlers, @model) ->

    @ractive = new Ractive

      el: 'output'
      template: ractiveTemplate
      data: @_buildRactiveData(model)
    @ractive.on ractiveHandlers
    @_setRactiveObservers()
  _buildRactiveData: ->
  _setRactiveObservers: ->
  set: (keypath, value) => @ractive.set keypath, value
  get: (keypath) => @ractive.get keypath

class Model

  # TODO: consolidate
  # TODO: write unit-tests
  getSprint: (sprintId, successCb) ->
    
    $.ajaxq 'client',

      url: "/sprint/#{sprintId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        console.log 'error: #{data}'
  getStory: (storyId, successCb) ->
    
    $.ajaxq 'client',

      url: "/story/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        console.log 'error: #{data}'
  getSprints: (successCb) ->

    $.ajaxq 'client',

      url: '/sprint'
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

       console.log 'error: #{data}'
  getStories: (sprintId, successCb) ->

    $.ajaxq 'client',

      url: '/story'
      type: 'GET'
      headers: {parent_id: sprintId}
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

       console.log 'error: #{data}'
  requestChildUpdate: (index, key, value, successCb, errorCb) =>

    @_requestUpdate(@children.type, @children.objects[index]._id, key, value, @children.objects[index]._rev, successCb, errorCb)
  requestUpdate: (key, value, successCb, errorCb) =>

    @_requestUpdate(@type, @[@type]._id, key, value, @[@type]._rev, successCb, errorCb)
  _requestUpdate: (type, id, key, value, rev, successCb, undoCb) =>

    $.ajaxq 'client', 

      url: "/#{type}/#{id}"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: value}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', rev
      success: (data, textStatus, jqXHR) ->

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()
  get: (key) => @[@type]?[key]
  set: (key, value) => @[@type]?[value]

class ViewModel

  constructor: ->

    @ractiveHandlers =

      trigger_update: @triggerUpdate
      tapped_selector: @openSelectorPopup
      tapped_selector_item: @selectPopupItem
      tapped_button: @handleButton

  _initDatePickers: (options) =>

    $('.date-selector .content').datepicker

      inline: true
      showOtherMonths: true
      dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      nextText: '<div class="arrow right"></div>'
      prevText: '<div class="arrow left"></div>'
      dateFormat: $.datepicker.ISO_8601
      gotoCurrent: true
      onSelect: @_selectDate

    for key, value of options

      $('.date-selector .content').datepicker 'option', key, value
  _selectDate: (dateText, inst) =>

    dateSelector = $(inst.input).parents('.date-selector')
    @_hidePopup dateSelector.attr('id')
    $('document').unbind 'click', dateSelector.data 'close_handler'
    $('.selected', dateSelector).data 'date', dateText    
    $('.selected', dateSelector).text($.datepicker.formatDate common.DATE_DISPLAY_FORMAT, new Date(dateText))
    dateSelector
  _initPopupSelectors: =>

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    $('.popup-selector').each (index, element) =>

      closeHandler = (event) =>

        if ($(event.target).parents("##{element.id}").length == 0) && ($(event.target).parents('.ui-datepicker-header').length < 1)
        
          @_hidePopup(element.id)
          $(document).unbind 'click', closeHandler
      $('.selected', $(element)).click -> $(document).bind 'click', closeHandler
      $(element).data('close_handler', closeHandler)
  _setConfirmedValue: (node) ->

    key = node.id 
    value = @model.get key
    $(node).data 'confirmed_value', value
  _resetToConfirmedValue: (node) -> 

    key = node.id 
    @model.set key, $(node).data('confirmed_value')
  _isConfirmedValue: (node) ->

    key = node.id 
    value = @model.get key
    value == $(node).data('confirmed_value')
  _showPopup: (id) -> 

    contentHeight = $('#content').height()
    popupHeight = $("##{id} .content").height()
    footerHeight = $("#button-bar").height()
    $("##{id} .content").show()
    popupTop = $("##{id}").position()?.top

    $('#overlay').css({height: $(window).height() + 'px'}).show()
    if (popupTop + popupHeight) > (contentHeight + footerHeight)

      $('#content').css 'height', popupTop + popupHeight - footerHeight
  _hidePopup: (id) -> 

    $("##{id} .content").hide()
    $('#overlay').hide()
    $('#content').css('height', 'auto')
    $(document).unbind 'click', $("##{id}").data 'close_handler'
  _showError: (message) =>

    @view.set('error_message', message)
    $('#overlay').css({height: $(window).height() + 'px'}).show()
    $('#error-popup').show()
  openSelectorPopup: (ractiveEvent, id) =>

    @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    id = args.selector_id
    @_hidePopup id
    $(document).unbind 'click', $("##{id}").data 'close_handler'
  handleButton: (ractiveEvent, action) => 

    switch action

      when 'error_ok' then $('#error-popup, #overlay').hide()

  _buildUpdateCall: (node) =>

    key = node.id;
    value = @model.get key

    return =>

      successCb = (data) => 

        @view.set "#{@model.type}._rev", data.rev
        @view.set "#{@model.type}.#{key}", data.value
        if $(node).data('confirmed_value')? then @_setConfirmedValue node
      errorCb = => @view.set "#{@model.type}.#{key}", $(node).data('confirmed_value')

      if !@_isConfirmedValue(node) then @model.requestUpdate key, value, successCb, errorCb

  triggerUpdate: (ractiveEvent, delayed) =>

    clearTimeout @keyboardTimer

    event = ractiveEvent.original
    node = ractiveEvent.node

    if (node.localName == 'input') && (event.which == 13) then event.preventDefault()

    updateCall = @_buildUpdateCall node

    if node.localName.match(/^input$|^textarea$/) && $(node).data('validation')?

      if !$(node).data('validation') $(node).val() 

        @_resetToConfirmedValue(node)
        updateCall = -> $(node).next().show()  
      else $(node).next().hide()

    if delayed? 

      @keyboardTimer = setTimeout updateCall, common.KEYUP_UPDATE_DELAY 
    else 

      updateCall()
