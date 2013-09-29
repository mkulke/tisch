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

    breadcrumbs: 

      story: title: @model.story.title, id: @model.story._id
      sprint: title: @model.sprint.title, id: @model.sprint._id
    task: @model.task
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    stories: [@model.story]
    getDateIndex: @model.getDateIndex
    time_spent_index: @model.getDateIndex(@model.sprint)
    remaining_time_index: @model.getDateIndex(@model.sprint)
    formatTimeSpent: (timeSpent, index) ->

      if timeSpent[index]? then timeSpent[index]
      else 0
    formatRemainingTime: @model.formatRemainingTime
    formatDateIndex: (dateIndex) -> moment(dateIndex).format(common.DATE_DISPLAY_FORMAT)
    error_message: "Dummy message"
class TaskModel extends Model

  type: 'task'
  constructor: (@task, @story, @sprint) ->
  getDateIndex: (sprint) ->

    currentDate = new moment()
    sprintStart = new moment sprint.start
    sprintInclusiveEnd = sprintStart.clone().add('days', sprint.length - 1)
    dateIndex = 

      if currentDate < sprintStart then sprintStart
      else if currentDate > sprintInclusiveEnd then sprintInclusiveEnd 
      else currentDate
    dateIndex.format('YYYY-MM-DD')
  formatRemainingTime: (remainingTime, index, sprint) ->

    if remainingTime[index]? then remainingTime[index]
    else

      # in this case check for the next date w/ a value *before*, but *within* the sprint
      value = remainingTime.initial
      start = moment(sprint.start)

      indexDate = moment(index)
      while indexDate.subtract('days', 1) >= start

        if remainingTime[indexDate.format('YYYY-MM-DD')]?

          value = remainingTime[indexDate.format('YYYY-MM-DD')]
          break
      value
  set: (key, value, index) =>

    if index? then @[@type][key][index] = value
    else @[@type][key] = value

class TaskViewModel extends ViewModel

  constructor: (@model, ractiveTemplate) ->

    @view = new TaskView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new TaskSocketIO @view, @model

    $('#summary, #description, #initial_estimation, #remaining_time, #time_spent').each (index, element) => 

      @_setConfirmedValue(element)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> 

      value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
    @_initDatePickers 

      minDate: new Date @model.sprint.start
      maxDate: new Date ((new Date @model.sprint.start).getTime() + ((@model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
  _selectDate: (dateText, inst) =>

    super(dateText, inst)
    dateSelector = $(inst.input).parents('.date-selector')
    id = dateSelector.attr('id')
    @view.set id, dateText
  _setConfirmedValue: (node) ->

    key = node.id 
    if key.match /^remaining_time$|^time_spent$/

      valueObject = @model.get key
      newObject = {}
      for i of valueObject

        newObject[i] = valueObject[i]
      $(node).data 'confirmed_value', newObject
    else

      super node
  _isConfirmedValue: (node) ->

    key = node.id
    value = @view.get "task.#{key}"
    confirmedValue = $(node).data('confirmed_value')
    if key.match /^remaining_time$|^time_spent$/

        # ugly, but is sufficient here.
        JSON.stringify(confirmedValue) == JSON.stringify(value) 
    else 

      confirmedValue == value
  _buildUpdateCall: (node) =>

    call = super node

    key = node.id;
    if key.match /^remaining_time$|^time_spent$/

      #execute that stuff before the update call
      =>
      
        index = $("##{key}_index .selected").data 'date'
        value = parseFloat $(node).val(), 10
        @model.set key, value, index
        call()
    else call
  openSelectorPopup: (ractiveEvent, id) =>

    switch id
      
      when 'story-selector' then @model.getStories @model.story.sprint_id, (data) =>

        @view.set 'stories', data
        @_showPopup(id)
      else @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' 

        undoValue = @view.get 'color'
        @view.set 'task.color', args.value
        @model.update 'color'

          ,(data) => 

            @view.set 'task._rev', data.rev
          ,(message) =>

            @view.set 'task.color', undoValue
            #TODO: show error
      when 'story-selector' 

        undoValue = @view.get 'task.story_id'
        @view.set 'task.story_id', args.value
        @model.update 'story_id'

          ,(data) => 

            @view.set 'task._rev', data.rev
            @model.getStory data.value, (data) => 

              @view.set 'story', data
          ,(message) =>

            @view.set 'task.story_id', undoValue
            # TODO: show error
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'task_remove' 

        @showError 'Move along. This functionality is not implemented yet.'