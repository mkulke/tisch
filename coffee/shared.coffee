common = (->

  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  constants =

    en_US:

      COLOR: 'Color'
      INITIAL_ESTIMATION: 'Initial estimation'
      OK: 'Ok'
      REMAINING_TIME: 'Remaining time'
      REMOVE: 'Remove'
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

  getStory: (storyId, successCb) ->
    
    $.ajaxq 'client',

      url: "/story/#{storyId}"
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
  requestUpdate: (key, value, successCb, undoCb) =>

    $.ajaxq 'client', 

      url: "/#{@type}/#{@[@type]._id}"
      #url: "/task/#{@task._id}"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: value}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', @[@type]._rev
      success: (data, textStatus, jqXHR) ->

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()

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
  _setConfirmedValue: (node, value, index) ->

    #console.log("setConfirmedValue w/ #{value}, #{index}")
    if index?

      $(node).data 'confirmed_value', value[index]
    else 

      $(node).data 'confirmed_value', value
  _resetToConfirmedValue: (node, key, index) -> 

    #console.log("resetToConfirmedValue w/ #{key}, #{index}")
    if index?

      @model[@type][key][index] = $(node).data('confirmed_value')
    else

      @model[@type][key] = $(node).data('confirmed_value')
  _isConfirmedValue: (node, value, index) ->

    if index? 

      value[index] == $(node).data('confirmed_value')
    else

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
  _buildValue: (key) =>

    value = @model[@type][key]
    [value, undefined]
  openSelectorPopup: (ractiveEvent, id) =>

    @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    id = args.selector_id
    @_hidePopup id
    $(document).unbind 'click', $("##{id}").data 'close_handler'
  handleButton: (ractiveEvent, action) => 

    switch action

      when 'error_ok' then $('#error-popup, #overlay').hide()
  triggerUpdate: (ractiveEvent, delayed) =>

    clearTimeout @keyboardTimer
    event = ractiveEvent.original
    node = ractiveEvent.node
    if (node.localName == 'input') && (event.which == 13)

      event.preventDefault()

    key = node.id
    [value, index] = @_buildValue key

    updateCall = => 

      if !@_isConfirmedValue(node, value, index) then @model.requestUpdate key, value,

        (data) =>

          @view.set "#{@type}._rev", data.rev
          @view.set "#{@type}.#{key}", data.value
          @_setConfirmedValue node, data.value, index
        ,=> @view.set "#{@type}.#{key}", $(node).data('confirmed_value')

    if node.localName.match(/^input$|^textarea$/) && $(node).data('validation')?

      if !$(node).data('validation') $(node).val()

        @_resetToConfirmedValue(node, key, index)
        updateCall = -> $(node).next().show()  
      else

        $(node).next().hide()

    if delayed? 

      @keyboardTimer = setTimeout updateCall, common.KEYUP_UPDATE_DELAY 
    else 

      updateCall()