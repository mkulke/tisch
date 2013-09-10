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

  constructor: (ractive, model) ->

    socket = io.connect "http://#{window.location.hostname}"
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', (data) ->

      if data.message == 'update'
        
        for item in ['task', 'story'] when data.recipient == model[item]._id

          ractive.set "#{item}._rev", data.data.rev
          ractive.set "#{item}.#{data.data.key}", data.data.value
          if data.data.key == 'story_id' then model.reloadStory data.data.value, (data) -> ractive.set 'story', data

class RactiveView

  constructor: (template, ractiveHandlers, model) ->

    @ractive = new Ractive

      el: 'output'
      template: template
      data: 

        task: model.task
        story: model.story
        COLORS: common.COLORS
        constants: common.constants
        sprint: model.sprint
        test: common.test
        stories: [model.story]
        getIndexDate: model.getIndexDate
        remaining_time: model.getDateIndexedValue(model.task.remaining_time, model.getIndexDate(model.sprint), true)
        time_spent: model.getDateIndexedValue(model.task.time_spent, model.getIndexDate(model.sprint))
        error_message: "Dummy message"
    @ractive.on ractiveHandlers

    @ractive.observe "task.remaining_time", (newValue, oldValue) ->

      index = $("#remaining_time-index .selected").data 'date'
      @set 'remaining_time', model.task.remaining_time[index]
    , {init: false}
    @ractive.observe "task.time_spent", (newValue, oldValue) ->

      index = $("#time_spent-index .selected").data 'date'
      @set 'time_spent', model.task.time_spent[index]
    , {init: false}
  set: (keypath, value) => @ractive.set keypath, value
  get: (keypath) => @ractive.get keypath

class Model

  constructor: (@task, @story, @sprint) ->
  getIndexDate: (sprint, formatted) ->

    currentDate = new Date()
    sprintStart = new Date sprint.start
    sprintEnd = new Date(sprintStart.getTime() + (sprint.length - 1) * 86400000)   
    displayDate = currentDate if sprintStart <= currentDate <= sprintEnd
    displayDate = sprintStart if currentDate < sprintStart
    displayDate = sprintEnd if currentDate > sprintEnd

    format = $.datepicker.ISO_8601
    format = common.DATE_DISPLAY_FORMAT if formatted?

    $.datepicker.formatDate format, displayDate
  getDateIndexedValue: (map, indexDate, inherited) ->

    if map[indexDate]?

      value = map[indexDate]
    else if inherited == true 

      # in this case check for the next date w/ a value *before*, but *within* the sprint
      value = map.initial
      sprintStartMs = new Date(@sprint.start).getTime()
      sprintStartMs -= sprintStartMs % common.MS_TO_DAYS_FACTOR
      while sprintStartMs <= (ms = new Date(indexDate).getTime() - common.MS_TO_DAYS_FACTOR) 
      
        indexDate = $.datepicker.formatDate $.datepicker.ISO_8601, new Date(ms)
        if map[indexDate]? 

          value = map[indexDate]
          break
    else
      value = 0
    value 
  reloadStory: (storyId, successCb) ->
    
    $.ajaxq 'client',

      url: "/story/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        console.log 'error: #{data}'
  reloadStories: (sprintId, successCb) ->

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

      url: "/task/#{@task._id}"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: value}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', @task._rev
      success: (data, textStatus, jqXHR) ->

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()

class ViewModel

  constructor: (@model, ractiveTemplate) ->

    ractiveHandlers = 

      trigger_update: @triggerUpdate
      tapped_selector: @openSelectorPopup
      tapped_selector_item: @selectPopupItem
      tapped_button: @handleButton

    @ractive = new RactiveView ractiveTemplate, ractiveHandlers, @model
    @socketio = new SocketIO @ractive, @model

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    $('#summary, #description, #initial_estimation').each (index, element) => $(element).data 'confirmed_value', @ractive.get("task.#{this.id}")
    $('#remaining_time, #time_spent').each (index, element) => $(element).data 'confirmed_value', @ractive.get(element.id)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    $('.popup-selector').each (index, element) =>

      closeHandler = (event) =>

        #console.log "closeHandler called"

        if ($(event.target).parents("##{element.id}").length == 0) && ($(event.target).parents('.ui-datepicker-header').length < 1)
        
          @_hidePopup(element.id)
          $(document).unbind 'click', closeHandler
      $('.selected', $(element)).click -> $(document).bind 'click', closeHandler
      $(element).data('close_handler', closeHandler)

    $('.date-selector .content').datepicker 

      inline: true
      showOtherMonths: true
      dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      nextText: '<div class="arrow right"></div>'
      prevText: '<div class="arrow left"></div>'
      minDate: new Date @model.sprint.start
      maxDate: new Date ((new Date @model.sprint.start).getTime() + ((@model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
      dateFormat: $.datepicker.ISO_8601
      gotoCurrent: true
      onSelect: @_selectDate
  _selectDate: (dateText, inst) =>

    dateSelector = $(inst.input).parents('.date-selector')
    @_hidePopup dateSelector.attr('id')
    $('document').unbind 'click', dateSelector.data 'close_handler'
    $('.selected', dateSelector).data 'date', dateText    
    $('.selected', dateSelector).text($.datepicker.formatDate common.DATE_DISPLAY_FORMAT, new Date(dateText))
    attribute = dateSelector.attr('id').split('-')[0]
    @ractive.set attribute, @model.getDateIndexedValue(@model.task[attribute], dateText, attribute == 'remaining_time')
  _setConfirmedValue: (node, value, index) ->

    #console.log("setConfirmedValue w/ #{value}, #{index}")
    if index?

       $(node).data 'confirmed_value', value[index]
    else 

      $(node).data 'confirmed_value', value
  _resetToConfirmedValue: (node, key, index) -> 

    #console.log("resetToConfirmedValue w/ #{key}, #{index}")
    if index?

      @model.task[key][index] = $(node).data('confirmed_value')
    else

      @model.task[key] = $(node).data('confirmed_value')
  _isConfirmedValue: (node, value, index) ->

    if index? 

      value[index] == $(node).data('confirmed_value')
    else

      value == $(node).data('confirmed_value')
  _buildValue: (key) =>

    value = @model.task[key]
    if key == 'remaining_time'

      index = $('#remaining_time-index .selected').data 'date'
      value[index] = @ractive.get(key)
    else if key == 'time_spent'

      index = $('#time_spent-index .selected').data 'date'
      value[index] = @ractive.get(key)
    [value, index]
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
  #set = (keypath, value) => ractive.set keypath, value
  #get = (keypath) => ractive.get keypath
  _showError: (message) =>

    @ractive.set('error_message', message)
    $('#overlay').css({height: $(window).height() + 'px'}).show()
    $('#error-popup').show()
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

          @ractive.set 'task._rev', data.rev
          @ractive.set "task.#{key}", data.value
          @_setConfirmedValue node, data.value, index
        ,=> @ractive.set "task.#{key}", $(node).data('confirmed_value')

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
  openSelectorPopup: (ractiveEvent, id) =>

    switch id
      
      when 'story-selector' then @model.reloadStories @model.story.sprint_id, (data) =>

        @ractive.set 'stories', data
        @_showPopup(id)
      else @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    id = args.selector_id
    @_hidePopup id
    $(document).unbind 'click', $("##{id}").data 'close_handler'

    switch id

      when 'color-selector' then @model.requestUpdate 'color', args.value, (data) => 

        @ractive.set 'task._rev', data.rev
        @ractive.set 'task.color', data.value
      when 'story-selector' 

        @model.requestUpdate 'story_id', args.value, (data) => 

          @ractive.set 'task._rev', data.rev
          @ractive.set 'task.story_id', data.value
          @model.reloadStory data.value, (data) => 

            @ractive.set 'story', data
  handleButton: (ractiveEvent, action) => 

    switch action

      when 'error_ok' then $('#error-popup, #overlay').hide()
      when 'task_remove' then @_showError 'Move along. This functionality is not implemented yet.'