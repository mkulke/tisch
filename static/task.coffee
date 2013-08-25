common = (->

  COLORS = ['yellow', 'orange', 'red', 'purple', 'blue', 'green']
  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  {COLORS: COLORS, uuid: uuid}
)()

socketio = (->

  init = ->

    socket = io.connect 'http://' + window.location.hostname
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', ->

      if data.recipient == task._id

        if data.message == 'update'

          ractive.set 'task._rev', data.data._rev
          ractive.set 'task.' + data.data.key, data.data.value
  {init: init}
)()
socketio.init()

ractive = (->

  init = (template) ->

    ractive = new Ractive

      el: 'output',
      template: template,
      data: 

        task: taskView.objects().task
        COLORS: common.COLORS
        stories: [taskView.objects().story]
    ractive.on

      keypress: startUpdateTimer,
      keypress_ignore_return: (event) ->

        if event.original.which == 13

          event.original.preventDefault()
        startUpdateTimer event
      focusout: (event) ->

        clearTimeout keyboardTimer
        taskView.commitUserInput.call event.node
      select_focus: taskView.populateStorySelector

    ractive.observe 'task.color', taskView.commitUserInput.bind($('#color').get(0)), {init: false}
    ractive.observe 'task.story_id', taskView.commitUserInput.bind($('#story_id').get(0)), {init: false}

    $('input, textarea, select').each -> $(this).data 'confirmed_value', taskView.objects().task[this.id]
    $('#initial_estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0
  startUpdateTimer = (event) ->

    clearTimeout keyboardTimer
    keyboardTimer = setTimeout taskView.commitUserInput.bind event.node, 1500
  set = (keypath, value) ->

    ractive.set keypath, value
  get = (keypath) ->

    ractive.get keypath
  {init: init, set: set, get: get}
)()

taskView = ( ->

  task = story = null

  init = (aTask, aStory) ->

    task = aTask
    story = aStory

  populateStorySelector = ->

    sprint_id = story.sprint_id for story in ractive.get('stories') when story._id == task.story_id

    $.ajaxq 'client',

      url: '/story'
      type: 'GET'
      headers: {parent_id: sprint_id}
      dataType: 'json'
      success (data, textStatus, jqXHR) ->

        ractive.set 'stories', data
      error (data, textStatus, jqXHR) ->

        alert 'error!'
  commitUserInput = ->

    if $(this).data('validation')?

      if !$(this).data('validation') $(this).val()

        task[this.id] = $(this).data('confirmed_value')
        $(this).next().show()
        false
      else

        $(this).next().hide()
    key = this.id
    value = task[key]

    requestUpdate key, value, (value) ->

      $(this).data 'confirmed_value', value
    , ->

      ractive.set "task.#{ this.id }", $(this).data('confirmed_value')      
  requestUpdate = (key, value, successCb, undoCb) ->

    $.ajaxq 'client', 

      url: "/task/#{ task._id }"
      type: 'POST'
      headers: {client_uuid: common.uuid}
      contentType: 'application/json'
      data: JSON.stringify {key: key, value: value}
      beforeSend: (jqXHR, settings) ->

        jqXHR.setRequestHeader 'rev', task._rev
      success: (data, textStatus, jqXHR) ->

        ractive.set 'task._rev', data.rev
        ractive.set "task.#{ key }", data.value
        if successCb?

          successCb data.value
      error: (data, textStatus, jqXHR) ->

        alert 'error!'
        if undoCb?

          undoCb()

  objects = ->

    {task: task, story: story}

  {init: init, commitUserInput: commitUserInput, populateStorySelector: populateStorySelector, objects: objects};
)()
