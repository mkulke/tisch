common = (->

  COLORS = ['yellow', 'orange', 'red', 'purple', 'blue', 'green']
  uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->

    r = Math.random() * 16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString 16
  constants =

    en_US:

      COLOR: 'Color'
      INITIAL_ESTIMATION: 'Initial estimation'
      REMAINING_TIME: 'Remaining time'
      STORY: 'Story'
      TIME_SPENT: 'Time spent'
      TODAY: 'today'
      VALID_TIME_MESSAGE: 'This attribute has to be specified as a positive number < 100 with two or less precision digits (e.g. "1" or "99.25").'
  {COLORS: COLORS, uuid: uuid, constants: constants}
)()

socketio = (->

  init = ->

    socket = io.connect "http://#{window.location.hostname}"
    socket.on 'connect', -> socket.emit 'register', {client_uuid: common.uuid}
    socket.on 'message', (data) ->

      if data.message == 'update'
        
        for item in ['task', 'story'] when data.recipient == model[item]._id

          view.set "#{item}._rev", data.data.rev
          view.set "#{item}.#{data.data.key}", data.data.value  
  {init: init}
)()

model = (->

  init = (@task, @story) ->
  {init: init, task: this.task, story: this.story, test: -> 3 + 5}
)()

view = (->

  init = (template) =>

    @ractive = new Ractive

      el: 'output'
      template: template
      data: 

        task: model.task
        story: model.story
        COLORS: common.COLORS
        constants: common.constants
        stories: [model.story]
        remaining_time: model.task.remaining_time.initial
        time_spent: model.task.time_spent.initial
    @ractive.on

      keyup: triggerUpdateTimer
      focusout: (event) =>

        clearTimeout @keyboardTimer
        controller.commitUserInput.call event.node
      select_focus: controller.populateStorySelector
      tapped_color_selector: (event) -> $(event.node).next().show()  
      tapped_story_selector: (event) ->

        controller.populateStorySelector()
        $(event.node).next().show()
      tapped_color_item: (event) -> 

        $(event.node).parent('.content').hide()
        controller.requestUpdate 'color', $(event.node).data('color')
      tapped_story_item: (event) -> 

        $(event.node).parent('.content').hide()
        controller.requestUpdate 'story_id', $(event.node).data('id'), (data) -> controller.reloadStory data
    @ractive.observe 'task.color', controller.commitUserInput.bind($('#color').get(0)), {init: false}
    @ractive.observe 'task.story_id', controller.commitUserInput.bind($('#story_id').get(0)), {init: false}

    $('.popup-selector a.open').click (event) -> event.preventDefault()
    that = this
    $('input, textarea, select').each -> 

      $(this).data 'confirmed_value', that.ractive.get(this.id)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    $('#story-selector, #color-selector').each ->

      closeHandler = (event) =>

        if $(event.target).parents("##{this.id}").length == 0    
        
          $("##{this.id} .content").hide()
          $(document).unbind 'click', closeHandler
      $('.selected', $(this)).click -> $(document).bind 'click', closeHandler 
  triggerUpdateTimer = (event) =>

    if (event.node.localName == 'input') && (event.original.which == 13)

      event.original.preventDefault()
    clearTimeout @keyboardTimer
    @keyboardTimer = setTimeout controller.commitUserInput.bind(event.node), 1500
  set = (keypath, value) =>

    @ractive.set keypath, value
  get = (keypath) =>

    @ractive.get keypath
  {init: init, set: set, get: get}
)()

controller = ( ->

  reloadStory = (id) ->
    
    $.ajaxq 'client',

      url: "/story/#{id}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> 

        view.set 'story', data
      error: (data, textStatus, jqXHR) -> alert 'error!'
  populateStorySelector = ->

    sprint_id = story.sprint_id for story in view.get('stories') when story._id == model.task.story_id

    $.ajaxq 'client',

      url: '/story'
      type: 'GET'
      headers: {parent_id: sprint_id}
      dataType: 'json'
      success: (data, textStatus, jqXHR) -> view.set 'stories', data
      error: (data, textStatus, jqXHR) -> alert 'error!'
  commitUserInput = ->

    if $(this).data('validation')?

      if !$(this).data('validation') $(this).val()

        model.task[this.id] = $(this).data('confirmed_value')
        $(this).next().show()
        return false
      else

        $(this).next().hide()
    key = this.id

    if this.id == 'remaining_time' || this.id == 'time_spent'

      value = model.task[key]
      index = $(this).prev().val()
      value[index] = view.get(this.id)
    else
      
      value = model.task[key]

    requestUpdate key, value, (value) ->

      $(this).data 'confirmed_value', value
    , ->

      view.set "task.#{this.id}", $(this).data('confirmed_value')      
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

        view.set 'task._rev', data.rev
        view.set "task.#{key}", data.value
        if successCb?

          successCb data.value
      error: (data, textStatus, jqXHR) ->

        console.log "error: #{data}"
        if undoCb?

          undoCb()
  {commitUserInput: commitUserInput, populateStorySelector: populateStorySelector, requestUpdate: requestUpdate, reloadStory: reloadStory};
)()