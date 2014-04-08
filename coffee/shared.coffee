partial = (fn) ->

  aps = Array.prototype.slice
  args = aps.call arguments, 1
  
  -> 

    fn.apply @, args.concat(aps.call(arguments))

equals = (a, b) ->

  a == b

at = (arr, index) ->

  arr[index]

curry2 = (fn) ->

  (arg2) ->

    (arg1) ->

      fn arg1, arg2

curry3 = (fn) ->

  (arg3) ->
    
    (arg2) ->

      (arg1) ->

        fn arg1, arg2, arg3

add = (a, b) ->

  a + b

sum = curry3(_.reduce)(0)(add)

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
    KEYUP_UPDATE_DELAY: 500
    DATE_DISPLAY_FORMAT: 'MM/DD/YY'
    DATE_DB_FORMAT: 'YYYY-MM-DD'
    TIME_REGEX: /^\d{1,2}(\.\d{1,2}){0,1}$/
    ###COLOR_SELECTOR: 1
    STORY_SELECTOR: 2
    REMAINING_TIME_DATEPICKER: 3###
  }
)()

class SocketIO

  arrayify = (fn) ->

    return ->

      argument = _.first(arguments)
      array = if _.isArray argument then argument else [argument]
      fn.call @, array

  _registrations: []

  registerWires: arrayify (wires) ->

    registrations = _.map wires, (wire) ->

      _.extend wire, {index: _.uniqueId()}
      server: _.omit wire, 'handler'
      client: {index: wire.index, handler: wire.handler} 
    @server.emit 'register', _.pluck registrations, 'server'
    @_registrations = @_registrations.concat _.pluck registrations, 'client'

  unregisterWires: arrayify (wires) ->

    indices = _.pluck wires, 'index'
    unregistered = (wire) ->

      _.contains indices, wire.index
    @_registrations = _.reject @_registrations, unregistered
    @server.emit 'unregister', indices

  connect: (connectedCb) ->

    @server = io.connect "http://#{window.location.hostname}"
    onConnect = =>

      connectedCb @server.socket?.sessionid
    @server.on 'connect', onConnect
    onNotify = (data) =>

      registration = _.findWhere @_registrations, {index: data.index}
      registration?.handler? data.data
    @server.on 'notify', onNotify
    onDisconnect = =>

      @_registrations = []
    @server.on 'disconnect', onDisconnect

#TODO: refactor in functional code
class Chart 

  constructor: (lines = []) ->

    format = d3.time.format("%Y-%m-%d")

    @valueFn = (d) -> d.value
    @dateFn = (d) -> format.parse d.date

    padding = $('#stats-dialog .content').css('padding')
    width = 365
    #width = $('#stats-dialog .content').width() - $('#stats-dialog .textbox').width()
    height = $('#stats-dialog').height() - $('#stats-dialog .popup-buttons').height() - 2 * parseInt(padding)

    @xScale = d3.time.scale().range([20, width - 10])
    @yScale = d3.scale.linear().range([height - 20, 5])

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
      .attr("width", width)
      .attr("height", height)

    @svg.append("svg:path").attr('class', "#{line} line") for line in lines

    @svg.append("g")         
      .attr("class", "y axis")
      .attr("transform", "translate(20, 0)")
    @svg.append("g")         
      .attr("class", "x axis")
      .attr("transform", "translate(0, #{height - 20})")

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

      circles.exit()
        .remove()

      if circles.empty()

        @svg.select("path.#{path}").remove()
      else

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

  remove = (type, item, successCb, errorCb) ->

    getRev = ->

      item._rev
    $.ajaxq 'client',

      url: "/#{type}/#{item._id}"
      type: 'DELETE'
      headers: {client_uuid: common.uuid, sessionid: @sessionid}
      beforeSend: (jqXHR, settings) =>

        jqXHR.setRequestHeader 'rev', getRev()
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (jqXHR, textStatus, errorThrown) -> 

        errorCb? (if errorThrown == "" then 'Error: Unknown communications problem with server.' else errorThrown)
  create = (type, parentId, successCb, errorCb) ->

    headers = {client_uuid: common.uuid, sessionid: @sessionid}
    if parentId?

      headers.parent_id = parentId

    $.ajaxq 'client',

      url: "/#{type}"
      type: 'PUT'
      headers: headers
      success: (data, textStatus, jqXHR) -> 

        successCb? data.new
      error: (jqXHR, textStatus, errorThrown) -> 

        # TODO: proper err msg
        #msgFunction = common.constants.en_US["ERROR_CREATE_#{type}"]
        errorCb? #{errorThrown}
  get = (type, id, successCb, errorCb) ->

    $.ajaxq 'client',

      url: "/#{type}/#{id}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        successCb? data
      error: (jqXHR, textStatus, errorThrown) -> 

        #TODO: proper errmsg
        errorCb? errorThrown
  getMultiple = (type, parentId, sortBy, successCb) ->

    headers = {}

    if parentId? 

      _.extend headers, {parent_id: parentId}
    if sortBy?

      _.extend headers, {sort_by: sortBy}

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

  createTask: partial create, 'task'
  createStory: partial create, 'story'
  createSprint: partial create, 'sprint', null
  removeTask: partial remove, 'task'
  removeStory: partial remove, 'story'  
  removeSprint: partial remove, 'sprint'
  getTask: partial get, 'task'
  getStory: partial get, 'story'
  getSprint: partial get, 'sprint'
  #getTasks: partial getMultiple, 'task'
  getStories: partial getMultiple, 'story'
  getSprints: partial getMultiple, 'sprint', null

  update: (object, key, type, successCb, errorCb) =>

    getRev = ->

      object._rev

    $.ajaxq 'client', 

      url: "/#{type}/#{object._id}"
      type: 'POST'
      headers: {property: key, sessionid: @sessionid}
      contentType: 'application/json'
      dataType: 'json'
      data: JSON.stringify {key: key, value: object[key]}
      beforeSend: (jqXHR, settings) ->

        jqXHR.setRequestHeader 'rev', getRev()
      success: (data, textStatus, jqXHR) ->

        object._rev = data.rev
        successCb? data
      error: (jqXHR, textStatus, errorThrown) ->

        # TODO: i18n
        errorCb? (if errorThrown == "" then 'Error: Unknown communications problem with server.' else errorThrown)

  getClosestValueByDateIndex: (object, index, startIndex) ->

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
  buildSprintRange: (sprintStart, sprintLength) ->

    start = moment sprintStart
    end = moment(start).add 'days', sprintLength - 1
    start: start.format(common.DATE_DB_FORMAT), end: end.format(common.DATE_DB_FORMAT)
  _mostRecentValue: (pairs) ->

    _.chain(pairs).sortBy(_.first).last(2).first().last().value()
class ViewModel

  _createObservable: (updateModelFn, object, property, options = {}) ->

    instantaneousProperty = ko.observable(object[property])

    update = (observable, value) ->

      value = if options.time == true then parseFloat value, 10 else value
      if !instantaneousProperty.hasError?() && object[property] != value

        updateModelFn observable, object, property, value      

    if options.throttled == true

      observable = ko.computed(instantaneousProperty).extend({throttle: common.KEYUP_UPDATE_DELAY})
      observable.subscribe partial(update, observable)
    else 

      instantaneousProperty.subscribe partial(update, instantaneousProperty)

    if options.time == true

      instantaneousProperty.extend({matches: common.TIME_REGEX})
    instantaneousProperty

  # test, TODO: move to super class
  _createUpdateWire: (model, observables) ->

    id: model._id
    method: 'POST'
    properties: _.keys(observables)
    handler: (data) ->

      key = data.key
      value = data.value
      model._rev = data.rev
      model[key] = value
      observables[key] value

  _updateModel: (type, observable, object, property, value) =>

    oldValue = object[property]
    object[property] = value
    @model.update object, property, type, null, (message) =>

      object[property] = oldValue
      observable(oldValue)
      @_showError message

  _showError: (message) =>

    @errorMessage message
    @modal 'error-dialog'

  _afterConfirm: (message, fn) =>

    @confirmMessage message
    @modal 'confirm-dialog'
    @confirm = =>

      @modal null
      fn()

  cancelPopup: (data, event) =>

    if event.keyCode == 27 && @modal != null

      @modal null
  
  confirmError: => 

    @modal null

  showErrorDialog: (message) =>

    @modal 'error-dialog'
    @errorMessage message

  cancel: =>

    @modal null

  constructor: (@model) ->

    # markdown

    marked.setOptions

      gfm: true
      tables: true

    ko.extenders.matches = (target, regex) ->

      target.hasError = ko.observable()
      target.validationMessage = ko.observable()

      validate = (newValue) ->

        target.hasError(newValue.toString().search(regex) != 0)
      validate target()
      target.subscribe(validate)
      target

    ko.bindingHandlers.datepicker = 

      init: (element, valueAccessor, allBindingsAccessor) =>

        options =

          inline: true
          showOtherMonths: true
          dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
          nextText: '<div class="arrow right"></div>'
          prevText: '<div class="arrow left"></div>'
          dateFormat: $.datepicker.ISO_8601
          gotoCurrent: true
          onSelect: (dateText, inst) => 

            @modal null
            observable = valueAccessor()
            observable dateText

        if allBindingsAccessor().datepickerMin? 

          options.minDate = new Date(allBindingsAccessor().datepickerMin)
        if allBindingsAccessor().datepickerMax?

          options.maxDate = new Date(allBindingsAccessor().datepickerMax)
        $(element).datepicker options
      update: (element, valueAccessor, allBindingsAccessor) ->

        value = ko.utils.unwrapObservable valueAccessor()
        dateValue = $(element).datepicker().val()
        if value? && value != dateValue

          $(element).datepicker 'setDate', new Date(value)
        min = allBindingsAccessor().datepickerMin

        if allBindingsAccessor().datepickerMin? && moment($(element).datepicker('option', 'minDate')).format(common.DATE_DB_FORMAT) != allBindingsAccessor().datepickerMin

          $(element).datepicker('option', 'minDate', new Date(allBindingsAccessor().datepickerMin))
        if allBindingsAccessor().datepickerMax? && moment($(element).datepicker('option', 'maxDate')).format(common.DATE_DB_FORMAT) != allBindingsAccessor().datepickerMax

          $(element).datepicker('option', 'maxDate', new Date(allBindingsAccessor().datepickerMax))

    @common = common

    @modal = ko.observable null
    
    # we need that recalculation, so the footer stays on bottom even
    # with the absolute positionen popups.  
    @modal.subscribe (value) ->

      if value?

        contentHeight = $('#content').height()
        popupHeight = $("##{value} .content").height()
        footerHeight = $("#button-bar").height()
        popupTop = $("##{value}").position()?.top

        if (popupTop + popupHeight) > (contentHeight + footerHeight)

          $('#content').css 'height', popupTop + popupHeight - footerHeight
      else

        $('#content').css 'height', 'auto'

    @errorMessage = ko.observable()
    @confirmMessage = ko.observable()