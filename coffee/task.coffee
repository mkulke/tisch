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
          if data.data.key == 'story_id' then model.reloadStory data.data.value, (data) -> ractive.set 'story', data
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

      trigger_update: viewModel.triggerUpdate
      tapped_selector: viewModel.openSelectorPopup
      tapped_selector_item: viewModel.selectPopupItem
      tapped_button: viewModel.handleButton
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
  reloadStory = (storyId, successCb) ->
    
    $.ajaxq 'client',

      url: "/story/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) -> 

        console.log 'error: #{data}'
  reloadStories = (sprintId, successCb) ->

    $.ajaxq 'client',

      url: '/story'
      type: 'GET'
      headers: {parent_id: sprintId}
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        if successCb? then successCb data
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

        if successCb? then successCb data
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()
  {
    requestUpdate: requestUpdate
    reloadStory: reloadStory
    reloadStories: reloadStories
    init: init
    task: @task
    story: @story
    sprint: @sprint
    getDateIndexedValue: getDateIndexedValue
    getIndexDate: getIndexDate
  }
)()

viewModel = (->

  init = (ractiveTemplate) ->

    socketio.init()
    ractive.init ractiveTemplate

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    $('#summary, #description, #initial_estimation').each -> $(this).data 'confirmed_value', ractive.get("task.#{this.id}")
    $('#remaining_time, #time_spent').each -> $(this).data 'confirmed_value', ractive.get(this.id)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    $('.popup-selector').each ->

      closeHandler = (event) =>

        #console.log "closeHandler called"

        if ($(event.target).parents("##{this.id}").length == 0) && ($(event.target).parents('.ui-datepicker-header').length < 1)
        
          #$("##{this.id} .content").hide()
          hidePopup(this.id)
          $(document).unbind 'click', closeHandler
      $('.selected', $(this)).click -> $(document).bind 'click', closeHandler
      $(this).data('close_handler', closeHandler)

    $('.date-selector .content').datepicker 

      inline: true
      showOtherMonths: true
      dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      nextText: '<div class="arrow right"></div>'
      prevText: '<div class="arrow left"></div>'
      minDate: new Date model.sprint.start
      maxDate: new Date ((new Date model.sprint.start).getTime() + ((model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
      dateFormat: $.datepicker.ISO_8601
      gotoCurrent: true
      onSelect: selectDate
  selectDate = (dateText, inst) ->

    dateSelector = $(inst.input).parents('.date-selector')
    hidePopup dateSelector.attr('id')
    $('document').unbind 'click', dateSelector.data 'close_handler'
    $('.selected', dateSelector).data 'date', dateText    
    $('.selected', dateSelector).text($.datepicker.formatDate common.DATE_DISPLAY_FORMAT, new Date(dateText))
    attribute = dateSelector.attr('id').split('-')[0]
    ractive.set attribute, model.getDateIndexedValue(model.task[attribute], dateText, attribute == 'remaining_time')
  openSelectorPopup = (ractiveEvent, id) ->

    switch id
      
      when 'story-selector' then model.reloadStories model.story.sprint_id, (data) ->

        ractive.set 'stories', data
        showPopup(id)
      else showPopup(id)
  selectPopupItem = (ractiveEvent, args) ->

    id = args.selector_id
    hidePopup id
    $(document).unbind 'click', $("##{id}").data 'close_handler'

    switch id

      when 'color-selector' then model.requestUpdate 'color', args.value, (data) -> 

        ractive.set 'task._rev', data.rev
        ractive.set 'task.color', data.value
      when 'story-selector' 

        model.requestUpdate 'story_id', args.value, (data) -> 

          ractive.set 'task._rev', data.rev
          ractive.set 'task.story_id', data.value
          model.reloadStory data.value, (data) -> 

            ractive.set 'story', data

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

      if !isConfirmedValue(node, value, index) then model.requestUpdate key, value,

        (data) ->

          ractive.set 'task._rev', data.rev
          ractive.set "task.#{key}", data.value
          setConfirmedValue(node, data.value, index)
        ,-> ractive.set "task.#{key}", $(node).data('confirmed_value')

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
  showPopup = (id) -> 

    contentHeight = $('#content').height()
    popupHeight = $("##{id} .content").height()
    footerHeight = $("#button-bar").height()
    $("##{id} .content").show()
    popupTop = $("##{id}").position()?.top

    $('#overlay').css({height: $(window).height() + 'px'}).show()
    if (popupTop + popupHeight) > (contentHeight + footerHeight)

      $('#content').css 'height', popupTop + popupHeight - footerHeight
  hidePopup = (id) -> 

    $("##{id} .content").hide()
    $('#overlay').hide()
    $('#content').css('height', 'auto')
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