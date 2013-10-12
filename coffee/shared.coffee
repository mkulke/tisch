common = (->

  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  constants =

    en_US:

      ADD_SPRINT: 'Add Sprint'
      ADD_STORY: 'Add Story'
      ADD_TASK: 'Add Task'
      CANCEL: 'Cancel'
      CLOSE: 'Close'
      COLOR: 'Color'
      CONFIRM: 'Confirm'
      CONFIRM_TASK_REMOVAL: (summary) -> "Do you really want to remove the task with the summary '#{summary}'?"
      CONFIRM_SPRINT_REMOVAL: (title) -> "Do you really want to remove the sprint with the title '#{title}' and all its assigned stories and tasks?"
      CONFIRM_STORY_REMOVAL: (title) -> "Do you really want to remove the story with the title '#{title}' and all its assigned tasks?"
      END_DATE: 'End date'
      ESTIMATION: 'Estimation'
      ERROR_CREATE_TASK: 'Could not create a new Task.'
      ERROR_CREATE_SPRINT: (reason) -> "Could not create a new Sprint (#{reason})."
      ERROR_CREATE_STORY: (reason) -> "Could not create a new the Story (#{reason})."
      ERROR_REMOVE_STORY: 'Could not remove the Story.'
      ERROR_REMOVE_TASK: 'Could not remove the Task.'
      ERROR_UPDATE_TASK: 'Could not update the Task.'
      INITIAL_ESTIMATION: 'Initial estimation'
      OK: 'Ok'
      OPEN: 'Open'
      REMAINING_TIME: 'Remaining time'
      REMOVE: 'Remove'
      SHOW_STATS: 'Show Stats'
      SPRINT: 'Sprint'
      START_DATE: 'Start date'
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
    DATE_DISPLAY_FORMAT: 'MM/DD/YY'
  }
)()

class SocketIO

  constructor: (@view, @model) ->

    socket = io.connect "http://#{window.location.hostname}"
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', @messageHandler    
  messageHandler: ->

class View

  constructor: (ractiveTemplate, @model) ->

    @ractive = new Ractive

      el: 'output'
      template: ractiveTemplate
      data: @_buildRactiveData(model)
  _buildRactiveData: ->
  setRactiveHandlers: (ractiveHandlers) =>

    @ractive.on ractiveHandlers
  update: (keypath) =>

    @ractive.update(keypath)
  set: (keypath, value) => 

    @ractive.set keypath, value
  get: (keypath) => 

    @ractive.get keypath

class Chart 

  constructor: (lines = []) ->

    format = d3.time.format("%Y-%m-%d")

    #chart = {}
    @valueFn = (d) -> d.value
    @dateFn = (d) -> format.parse d.date

    @xScale = d3.time.scale().range([25, 395])
    @yScale = d3.scale.linear().range([180, 5])

    @yAxis = d3.svg.axis()
      .scale(@yScale)
      .orient("left")
      .ticks(5)

    @xAxis = d3.svg.axis()
      .scale(@xScale)
      .orient("bottom")
      .tickFormat(d3.time.format('%e'))

    @lineGn = d3.svg.line()
      .x((d) => @xScale(@dateFn(d)))
      .y((d) => @yScale(@valueFn(d)))

    @svg = d3.select("#chart").append("svg:svg")
      .attr("width", 400)
      .attr("height", 200)

    @svg.append("svg:path").attr('class', "#{line} line") for line in lines

    @svg.append("g")         
      .attr("class", "y axis")
      .attr("transform", "translate(25, 0)")
    @svg.append("g")         
      .attr("class", "x axis")
      .attr("transform", "translate(0, 180)")

  _calculateChartRange: (object) =>

    allData = (value for key, value of object)

    yMax = allData.reduce (biggestMax, data) =>

      max = d3.max(data, @valueFn)
      if max > biggestMax then max
      else biggestMax
    , 0
    xMin = allData.reduce (smallestMin, data) =>

      min = d3.min(data, @dateFn)
      if !smallestMin? then smallestMin = min
      if min < smallestMin then min
      else smallestMin
    , null
    xMax = allData.reduce (biggestMax, data) =>

      max = d3.max(data, @dateFn)
      if max > biggestMax then max
      else biggestMax
    , 0
    return [yMax, xMin, xMax]

  refresh: (object) =>

    [yMax, xMin, xMax] = @_calculateChartRange object

    @xScale.domain([xMin, xMax])
    @yScale.domain([0, yMax])

    do (=>

      circles = @svg.selectAll("circle.#{path}").data(data)
  
      circles.transition()
        .attr("cx", (d) => @xScale(@dateFn(d)))
        .attr("cy", (d) => @yScale(@valueFn(d)))

      circles.enter()
        .append("svg:circle")
        .attr('class', "circle #{path}")
        .attr("r", 4)
        .attr("cx", (d) => @xScale(@dateFn(d)))
        .attr("cy", (d) => @yScale(@valueFn(d)))

      @svg.select("path.#{path}").datum(data)
        .transition()
        .attr("d", @lineGn)

      @svg.selectAll('g.y.axis')
        .call(@yAxis)
      @svg.selectAll('g.x.axis')
        .call(@xAxis)
    ) for path, data of object

class Model

  # TODO: consolidate
  # TODO: write unit-tests
  # TODO: more verbose error message, pass along those from http responses.

  remove = curry (type, item, successCb, errorCb) ->

    getRev = ->

      item._rev
    $.ajaxq 'client',

      url: "/#{type}/#{item._id}"
      type: 'DELETE'
      headers: {client_uuid: common.uuid}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', getRev()
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (data, textStatus, jqXHR) -> 

        msgFunction = common.constants.en_US["ERROR_REMOVE_#{type}"]
        errorCb? msgFunction #{jqXHR}
  create = curry (type, parentId, successCb, errorCb) ->

    headers = {client_uuid: common.uuid}
    if parentId?

      headers.parent_id = parentId

    $.ajaxq 'client',

      url: "/#{type}"
      type: 'PUT'
      headers: headers
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (data, textStatus, jqXHR) -> 

        msgFunction = common.constants.en_US["ERROR_CREATE_#{type}"]
        errorCb? msgFunction #{jqXHR}
  get = curry (type, id, successCb) ->

    $.ajaxq 'client',

      url: "/#{type}/#{id}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (data, textStatus, jqXHR) -> 

        #TODO: proper errmsg
        console.log 'error: #{data}'
  getMultiple = curry (type, parentId, successCb) ->

    if parentId?

      headers = {parent_id: parentId}
    else

      headers = {}

    $.ajaxq 'client',

      url: "/#{type}"
      type: 'GET'
      headers: headers
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (data, textStatus, jqXHR) -> 

        #TODO: proper errmsg
        console.log 'error: #{data}'    

  createTask: create 'task'
  createStory: create 'story'
  createSprint: create 'sprint', null
  removeTask: remove 'task'
  removeStory: remove 'story'  
  removeSprint: remove 'sprint'
  getTask: get 'task'
  getStory: get 'story'
  getSprint: get 'sprint'
  getTasks: getMultiple 'task'
  getStories: getMultiple 'story'
  getSprints: getMultiple 'sprint', null
  updateChild: (index, key, successCb, errorCb) => 

    @_update @children.objects[index], key, @children.type, successCb, errorCb
  update: (key, successCb, errorCb) => 

    @_update @[@type], key, @type, successCb, errorCb
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

        successCb? data
      error: (data, textStatus, jqXHR) ->

        errorCb? "#{common.constants.en_US.ERROR_UPDATE_TASK} #{jqXHR}"
  _getClosestValueByDateIndex: (object, index, startIndex) ->

    if object[index]?

      object[index]
    else

      sortedKeys = Object.keys(object).sort()
      filteredKeys = sortedKeys.filter (key) -> 

        index > key >= startIndex
      if filteredKeys.length > 0 

        object[filteredKeys.pop()]
      else

        object.initial
  get: (key) => @[@type]?[key]
  set: (key, value) => @[@type]?[value]

class ViewModel

  constructor: (@view, @model) ->

    ractiveHandlers =

      trigger_update: @triggerUpdate
      tapped_selector: @openSelectorPopup
      tapped_selector_item: @selectPopupItem
      tapped_button: @handleButton
    @view.setRactiveHandlers ractiveHandlers

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
    # rather put that in as a ractive variable? TODO: FIX THAT FOR SPRINTS, TOO!
    $('.selected', dateSelector).data 'date', dateText
    $('.selected', dateSelector).text moment(dateText).format(common.DATE_DISPLAY_FORMAT)
  _initPopupSelectors: =>

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    $('.popup-selector').each (index, element) =>

      $('.selected', $(element)).click => $(document).one 'keyup', (event) =>

        if event.keyCode == 27 then @_hidePopup(element.id)
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
  _showModal: (type, message) =>

    if message? then @view.set("#{type}_message", message)
    $('#overlay').css({height: $(window).height() + 'px'}).show()
    $("##{type}-dialog").show()
  showConfirm: (message) => @_showModal 'confirm', message
  showError: (message) => @_showModal 'error', message
  _hideModal: (type) -> $("##{type}-dialog, #overlay").hide()
  hideConfirm: -> @_hideModal 'confirm'
  hideError: -> @_hideModal 'error'
  openSelectorPopup: (ractiveEvent, id) =>

    @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    id = args.selector_id
    @_hidePopup id
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

    if (node.localName.match /^input$|^textarea$/)? && $(node).data('validation')?

      if !$(node).data('validation') $(node).val() 

        @_resetToConfirmedValue(node)
        updateCall = -> $(node).next().show()  
      else $(node).next().hide()

    if delayed? then @keyboardTimer = setTimeout updateCall, common.KEYUP_UPDATE_DELAY 
    else do updateCall

class ChildViewModel extends ViewModel

  constructor: (@view, @model) ->

    super(@view, @model)

    $('ul#well').sortable

      tolerance: 'pointer'
      delay: 150
      cursor: 'move'
      containment: 'ul#well'
      handle: '.header'
    $('ul#well').on 'sortstart', (event, ui) => 

      originalIndex = ui.item.index()
      $('ul#well').one 'sortstop', (event, ui) =>

        console.log 'sort stop'

        index = ui.item.index()
        if index != originalIndex then @_handleSortstop originalIndex, index
  _calculatePriority: (originalIndex, index) =>

    objects = @model.children.objects.slice()
    object = objects[originalIndex]
    objects.splice(originalIndex, 1)
    objects.splice(index, 0, object)

    if index == 0 then prevPrio = 0
    else prevPrio = objects[index - 1].priority

    last = objects.length - 1
    if index == last 

      Math.ceil objects[index - 1].priority + 1
    else

      nextPrio = objects[index + 1].priority
      (nextPrio - prevPrio) / 2 + prevPrio
  _setConfirmedValue: (node) ->

    [key, childIndex] = @_buildKey node
    if childIndex? then value = @model.children.objects[childIndex]?[key]
    else value = @model.get key
    $(node).data 'confirmed_value', value
  _resetToConfirmedValue: (node) -> 

    [key, childIndex] = @_buildKey node
    if childIndex? then @model.children.objects[childIndex]?[key] = $(node).data('confirmed_value')
    else value = @model.set key, $(node).data('confirmed_value')
  _isConfirmedValue: (node) ->

    [key, childIndex] = @_buildKey node
    if childIndex? then value = @model.children.objects[childIndex]?[key]
    else value = @model.get key
    value == $(node).data('confirmed_value')
  _handleSortstop: (originalIndex, index) => 

    priority = @_calculatePriority originalIndex, index
    undoValue = @model.children.objects[originalIndex].priority
    @model.children.objects[originalIndex].priority = priority
    @model.updateChild originalIndex, 'priority'

      ,(data) =>

        @model.children.objects[originalIndex]._rev = data.rev
      ,(message) =>

        @model.children.objects[originalIndex].priority = undoValue
        li = $("ul#well li:nth-child(#{index + 1})")
        li.detach()
        $("ul#well li:nth-child(#{originalIndex})").after(li)
        @showError message
   _buildKey: (node) ->

    idParts = node.id.split('-')
    if idParts.length > 1 then [idParts[0], idParts[1]]
    else [idParts[0], undefined]
  _buildUpdateCall: (node) =>

    [key, childIndex] = @_buildKey node
    if childIndex? 

      value = @model.children.objects[childIndex]?[key]
      type = @model.children.type
    else 

      type = @model.type
      value = @model[type][key]

    return =>

      successCb = (data) => 

        if childIndex? then keypathPrefix = "children[#{childIndex}]"
        else keypathPrefix = "#{type}"
        @view.set "#{keypathPrefix}._rev", data.rev
        @view.set "#{keypathPrefix}.#{key}", data.value
        if $(node).data('confirmed_value')? then @_setConfirmedValue node
      errorCb = => 

        if childIndex? then keypath = "children[#{childIndex}].#{key}"
        else keypath = "#{type}.#{key}"       
        @view.set keypath, $(node).data('confirmed_value')

      if !@_isConfirmedValue(node) 

        if childIndex? then @model.updateChild childIndex, key, successCb, errorCb
        else @model.update key, successCb, errorCb
  ###_debug_printPrio: (objects = @model.children.objects) =>

    for task in objects

      console.log "#{task.summary}: #{task.priority}"
  _debug_setPrio: (x = 1) =>
    
    i = 0
    objects = @model.children.objects #.slice()
    objects.sort (a, b) -> a.summary > b.summary ? -1 : 1
    for task in objects

      task.priority = i + x
      @model.updateChild i++, 'priority'
    @_debug_printPrio objects
  _setChildPriority: (index, priority) =>
    
    @view.set "children.#{index}.priority", priority
    @view.get('children').sort @_sortByPriority
  _sortChildren: =>

    objects = @model.children.objects.slice()
    objects.sort @_sortByPriority

  _sortByPriority: (a, b) ->

      a.priority > b.priority ? -1 : 1###
