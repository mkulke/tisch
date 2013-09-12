class TaskSocketIO extends SocketIO
  
  messageHandler: (data) =>

    if data.message == 'update'
        
        for item in ['task', 'story', 'sprint'] when data.recipient == @model[item]._id

          @view.set "#{item}._rev", data.data.rev
          @view.set "#{item}.#{data.data.key}", data.data.value
          switch data.data.key

            when 'story_id' then @model.getStory data.data.value, (data) => @view.set 'story', data
            when 'sprint_id' then @model.getSprint data.data.value, (data) => @view.set 'sprint', data

class TaskView extends View

  _buildRactiveData: =>

    task: @model.task
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    stories: [@model.story]
    getIndexDate: @model.getIndexDate
    remaining_time: @model.getDateIndexedValue(@model.task.remaining_time, @model.getIndexDate(@model.sprint), true)
    time_spent: @model.getDateIndexedValue(@model.task.time_spent, @model.getIndexDate(@model.sprint))
    error_message: "Dummy message"
  _setRactiveObservers: =>

    model = @model
    @ractive.observe "task.remaining_time", (newValue, oldValue) ->

      index = $("#remaining_time-index .selected").data 'date'
      @set 'remaining_time', model.task.remaining_time[index]
    , {init: false}
    @ractive.observe "task.time_spent", (newValue, oldValue) ->

      index = $("#time_spent-index .selected").data 'date'
      @set 'time_spent', model.task.time_spent[index]
    , {init: false}

class TaskModel extends Model

  type: 'task'
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
  set: (key, value, index) =>

    if index? then @[@type][key][index] = value
    else @[@type][key] = value

class TaskViewModel extends ViewModel

  constructor: (@model, ractiveTemplate) ->

    super()

    @view = new TaskView ractiveTemplate, @ractiveHandlers, @model
    @socketio = new TaskSocketIO @view, @model

    $('#summary, #description, #initial_estimation').each (index, element) => $(element).data 'confirmed_value', @view.get("task.#{this.id}")
    $('#remaining_time, #time_spent').each (index, element) => $(element).data 'confirmed_value', @view.get(element.id)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
    @_initDatePickers 

      minDate: new Date @model.sprint.start
      maxDate: new Date ((new Date @model.sprint.start).getTime() + ((@model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
  _selectDate: (dateText, inst) =>

    dateSelector = super(dateText, inst)
    attribute = dateSelector.attr('id').split('-')[0]
    @view.set attribute, @model.getDateIndexedValue(@model.task[attribute], dateText, attribute == 'remaining_time')
  _buildValue: (key) =>

    value = @model.task[key]
    if key == 'remaining_time'

      index = $('#remaining_time-index .selected').data 'date'
      value[index] = @view.get(key)
    else if key == 'time_spent'

      index = $('#time_spent-index .selected').data 'date'
      value[index] = @view.get(key)
    [value, index]
  _setConfirmedValue: (node) ->

    key = node.id 
    [value, index] = @_buildValue key

    if index? $(node).data 'confirmed_value', value[index]
    else $(node).data 'confirmed_value', value
  _resetToConfirmedValue: (node) -> 

    key = node.id 
    [value, index] = @_buildValue key

    if index? then @model.set key, $(node).data('confirmed_value'), index
    else @model.set key, $(node).data('confirmed_value')
  _isConfirmedValue: (node) ->

    key = node.id 
    [value, index] = @_buildValue key

    if index? value[index] == $(node).data('confirmed_value')
    else value == $(node).data('confirmed_value')
  openSelectorPopup: (ractiveEvent, id) =>

    switch id
      
      when 'story-selector' then @model.getStories @model.story.sprint_id, (data) =>

        @view.set 'stories', data
        @_showPopup(id)
      else @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' then @model.requestUpdate 'color', args.value, (data) => 

        @view.set 'task._rev', data.rev
        @view.set 'task.color', data.value
      when 'story-selector' 

        @model.requestUpdate 'story_id', args.value, (data) => 

          @view.set 'task._rev', data.rev
          @view.set 'task.story_id', data.value
          @model.getStory data.value, (data) => 

            @view.set 'story', data
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'task_remove' then @_showError 'Move along. This functionality is not implemented yet.'