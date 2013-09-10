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
