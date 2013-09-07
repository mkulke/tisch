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

socketio = (->

  init = ->

    socket = io.connect "http://#{window.location.hostname}"
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', (data) ->

      if data.message == 'update'
        
        for item in ['task', 'story'] when data.recipient == model[item]._id

          ractive.set "#{item}._rev", data.data.rev
          ractive.set "#{item}.#{data.data.key}", data.data.value
          controller.reloadStory data.data.value if data.data.key == 'story_id'
  {init: init}
)()

ractive = (->

  init = (template) =>

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
        error_message: "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et"
    @ractive.on

      trigger_update: view.triggerUpdate
      tapped_selector: view.openSelectorPopup
      tapped_selector_item: view.selectPopupItem
      tapped_button: view.handleButton
  set = (keypath, value) => @ractive.set keypath, value
  get = (keypath) => @ractive.get keypath
  {init: init, set: set, get: get} 
)()

model = (->

  getIndexDate = (sprint, formatted) ->

    currentDate = new Date()
    sprintStart = new Date sprint.start
    sprintEnd = new Date(sprintStart.getTime() + (sprint.length - 1) * 86400000)   
    displayDate = currentDate if sprintStart <= currentDate <= sprintEnd
    displayDate = sprintStart if currentDate < sprintStart
    displayDate = sprintEnd if currentDate > sprintEnd

    format = $.datepicker.ISO_8601
    format = common.DATE_DISPLAY_FORMAT if formatted?

    $.datepicker.formatDate format, displayDate
  getDateIndexedValue = (map, indexDate, inherited) ->

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
  init = (@task, @story, @sprint) ->
  {
    init: init
    task: @task
    story: @story
    sprint: @sprint
    getDateIndexedValue: getDateIndexedValue
    getIndexDate: getIndexDate
  }
)()

view = (->

  init = ->

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    $('#summary, #description, #initial_estimation').each -> $(this).data 'confirmed_value', ractive.get("task.#{this.id}")
    $('#remaining_time, #time_spent').each -> $(this).data 'confirmed_value', ractive.get(this.id)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    #$('#story-selector, #color-selector, #date-selector').each ->
    $('.popup-selector').each ->

      closeHandler = (event) =>

        #console.log "closeHandler called"

        if ($(event.target).parents("##{this.id}").length == 0) && ($(event.target).parents('.ui-datepicker-header').length < 1)
        
          $("##{this.id} .content").hide()
          $(document).unbind 'click', closeHandler
      $('.selected', $(this)).click -> $(document).bind 'click', closeHandler
      $(this).data('close_handler', closeHandler)

    $('.date-selector .content').datepicker 
    #$('#remaining_time_date-selector .content').datepicker {  

      inline: true
      showOtherMonths: true
      dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      nextText: '<img src="/right.png" alt="next">'
      prevText: '<img src="/left.png" alt="prev">'
      minDate: new Date model.sprint.start
      maxDate: new Date ((new Date model.sprint.start).getTime() + ((model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
      dateFormat: $.datepicker.ISO_8601
      gotoCurrent: true
      onSelect: selectDate
  selectDate = (dateText, inst) ->

    dateSelector = $(inst.input).parents('.date-selector')
    $('.content', dateSelector).hide()
    $('document').unbind 'click', dateSelector.data 'close_handler'
    $('.selected', dateSelector).data 'date', dateText    
    $('.selected', dateSelector).text($.datepicker.formatDate common.DATE_DISPLAY_FORMAT, new Date(dateText))
    attribute = dateSelector.attr('id').split('-')[0]
    ractive.set attribute, model.getDateIndexedValue(model.task[attribute], dateText, attribute == 'remaining_time')
  openSelectorPopup = (ractiveEvent, id) ->

    $("##{id} .content").show()

    switch id
      
      when 'story-selector' then controller.reloadStories model.story.sprint_id
  selectPopupItem = (ractiveEvent, args) ->

    id = args.selector_id
    $("##{id} .content").hide()
    $(document).unbind 'click', $("##{id}").data 'close_handler'

    switch id

      when 'color-selector' then controller.requestUpdate 'color', args.value
      when 'story-selector' then controller.requestUpdate 'story_id', args.value, (data) -> controller.reloadStory data
  setConfirmedValue = (node, value, index) ->

    #console.log("setConfirmedValue w/ #{value}, #{index}")
    if index?

       $(node).data 'confirmed_value', value[index]
    else 

      $(node).data 'confirmed_value', value
  resetToConfirmedValue = (node, key, index) -> 

    #console.log("resetToConfirmedValue w/ #{key}, #{index}")
    if index?

      model.task[key][index] = $(node).data('confirmed_value')
    else

      model.task[key] = $(node).data('confirmed_value')
  isConfirmedValue = (node, value, index) ->

    if index? 

      value[index] == $(node).data('confirmed_value')
    else

      value == $(node).data('confirmed_value')

  buildValue = (key) ->

    value = model.task[key]
    if key == 'remaining_time'

      index = $('#remaining_time-index .selected').data 'date'
      value[index] = ractive.get(key)
    else if key == 'time_spent'

      index = $('#time_spent_date-index .selected').data 'date'
      value[index] = ractive.get(key)
    [value, index]

  triggerUpdate = (ractiveEvent, delayed) =>

    clearTimeout @keyboardTimer
    event = ractiveEvent.original
    node = ractiveEvent.node
    if (node.localName == 'input') && (event.which == 13)

      event.preventDefault()

    key = node.id
    [value, index] = buildValue key

    updateCall = -> 

      if !isConfirmedValue(node, value, index) then controller.requestUpdate key, value,

        (value) -> setConfirmedValue(node, value, index),
        -> ractive.set "task.#{key}", $(node).data('confirmed_value')

    if node.localName.match(/^input$|^textarea$/) && $(node).data('validation')?

      if !$(node).data('validation') $(node).val()

        resetToConfirmedValue(node, key, index)
        updateCall = -> $(node).next().show()  
      else

        $(node).next().hide()

    if delayed? 

      @keyboardTimer = setTimeout updateCall, common.KEYUP_UPDATE_DELAY 
    else 

      updateCall()
  showPopup = (id) -> $("##{id} .content").show()
  hidePopup = (id) -> 

    $("##{id} .content").hide()
    $(document).unbind 'click', $("##{id}").data 'close_handler'
  set = (keypath, value) => ractive.set keypath, value
  get = (keypath) => ractive.get keypath
  showError = (message) ->

    ractive.set('error_message', message)
    $('#overlay').css({height: $(window).height() + 'px'}).show()
    $('#error-popup').show()
  handleButton = (ractiveEvent, action) -> 

    switch action

      when 'error_ok' then $('#error-popup, #overlay').hide()
      when 'task_remove' then showError 'Move along. This functionality is not implemented yet.'
  {
    init: init
    openSelectorPopup: openSelectorPopup
    selectPopupItem: selectPopupItem
    triggerUpdate: triggerUpdate
    handleButton: handleButton
  }
)()

controller = ( ->

  reloadStory = (storyId) ->
    
    $.ajaxq 'client',

      url: "/story/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        ractive.set 'story', data
      error: (data, textStatus, jqXHR) -> 

        console.log 'error: #{data}'
  reloadStories = (sprintId) ->

    $.ajaxq 'client',

      url: '/story'
      type: 'GET'
      headers: {parent_id: sprintId}
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        ractive.set 'stories', data
      error: (data, textStatus, jqXHR) ->

       console.log 'error: #{data}'
  requestUpdate = (key, value, successCb, undoCb) ->

    $.ajaxq 'client', 

      url: "/task/#{model.task._id}"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: value}
      beforeSend: (jqXHR, settings) ->

        jqXHR.setRequestHeader 'rev', model.task._rev
      success: (data, textStatus, jqXHR) ->

        ractive.set 'task._rev', data.rev
        ractive.set "task.#{key}", data.value
        if successCb?

          successCb data.value
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()
  {
    requestUpdate: requestUpdate
    reloadStory: reloadStory
    reloadStories: reloadStories
  }
)()