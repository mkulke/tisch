common = (->

  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  constants =

    en_US:

      ADD_TASK: 'Add Task'
      CANCEL: 'Cancel'
      COLOR: 'Color'
      CONFIRM: 'Confirm'
      ESTIMATION: 'Estimation'
      ERROR_CREATE_TASK: 'Could not create a new Task.'
      ERROR_REMOVE_STORY: 'Could not remove the Story. This functionality is not implemented yet.'
      ERROR_REMOVE_TASK: 'Could not remove the Task.'
      ERROR_UPDATE_TASK: 'Could not update the Task.'
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
      modifyArrays: false
    @ractive.on ractiveHandlers
    @_setRactiveObservers()
  _buildRactiveData: ->
  _setRactiveObservers: ->
  update: => @ractive.update()
  set: (keypath, value) => @ractive.set keypath, value
  get: (keypath) => @ractive.get keypath

class Model

  # TODO: consolidate
  # TODO: write unit-tests
  # TODO: more verbose error message, pass along those from http responses.

  createTask: (storyId, successCb, errorCb) ->

    $.ajaxq 'client',

      url: '/task'
      type: 'PUT'
      headers: {client_uuid: common.uuid, parent_id: storyId}
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        if errorCb? then errorCb "#{common.constants.en_US.ERROR_CREATE_TASK} #{jqXHR}"
  removeTask: (task, successCb, errorCb) ->

    getRev = -> 

      task._rev

    $.ajaxq 'client',

      url: "/task/#{task._id}"
      type: 'DELETE'
      headers: {client_uuid: common.uuid}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', getRev()
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        if errorCb? then errorCb "#{common.constants.en_US.ERROR_REMOVE_TASK} #{jqXHR}"
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
  removeStory: (storyId, successCb, errorCb) ->

    errorCb common.constants.en_US.ERROR_REMOVE_STORY
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
  updateChild: (index, key, successCb, errorCb) => @_update @children.objects[index], key, @children.type, successCb, errorCb
  update: (key, successCb, errorCb) => @_update @[@type], key, @type, successCb, errorCb
  _update: (object, key, type, successCb, errorCb) =>

    getRev = ->

      object._rev

    $.ajaxq 'client', 

      url: "/#{type}/#{object._id}"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: object[key]}
      beforeSend: (jqXHR, settings) ->

        jqXHR.setRequestHeader 'rev', getRev()
      success: (data, textStatus, jqXHR) ->

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

        if errorCb? then errorCb "#{common.constants.en_US.ERROR_UPDATE_TASK} #{jqXHR}"
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
  _showModal: (type, message) =>

    @view.set("#{type}_message", message)
    $('#overlay').css({height: $(window).height() + 'px'}).show()
    $("##{type}-popup").show()   
  showConfirm: (message) => @_showModal 'confirm', message
  showError: (message) => @_showModal 'error', message
  _hideModal: (type) -> 

    $("##{type}-popup, #overlay").hide()
  hideConfirm: -> 

    @_hideModal 'confirm'
  hideError: -> @_hideModal 'error'
  openSelectorPopup: (ractiveEvent, id) =>

    @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    id = args.selector_id
    @_hidePopup id
    $(document).unbind 'click', $("##{id}").data 'close_handler'
  handleButton: (ractiveEvent, action) => 

    switch action

      when 'error_ok' then @hideError()
      when 'confirm_cancel' then @hideConfirm()
      when 'confirm_confirm' then @hideConfirm()

  _buildUpdateCall: (node) =>

    key = node.id;
    value = @model.get key

    return =>

      undoValue = @view.get "#{@model.type}.#{key}"
      successCb = (data) => 

        @view.set "#{@model.type}._rev", data.rev
        if $(node).data('confirmed_value')? then @_setConfirmedValue node
      errorCb = => 

        @view.set "#{@model.type}.#{key}", undoValue
      if !@_isConfirmedValue(node) 

        @view.set "#{@model.type}.#{key}", value
        @model.update key, successCb, errorCb

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
