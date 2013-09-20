class StorySocketIO extends SocketIO

  messageHandler: (data) =>

    if data.message == 'update'
        
      #TODO: tasks
      if @view.get('story')._id == data.recipient

        @view.set "story._rev", data.data.rev
        @view.set "story.#{data.data.key}", data.data.value
        if data.data.key == 'sprint_id' 

          @model.getSprint data.data.value, (data) => 

            @view.set 'sprint', data
      else if @view.get('sprint')._id == data.recipient

        @view.set "sprint._rev", data.data.rev
        @view.set "sprint.#{data.data.key}", data.data.value
      else

        index = i for child, i in @view.get('children') when child._id == data.recipient

        if index?

          @view.set "children.#{index}._rev", data.data.rev
          @view.set "children.#{index}.#{data.data.key}", data.data.value
          if data.data.key == 'priority' then @view.get('children').sort (a, b) -> a.priority > b.priority ? -1 : 1

class StoryView extends View

  _buildRactiveData: =>

    children: @model.children.objects
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    sprints: [@model.sprint]
    error_message: "Dummy message"
    confirm_message: "Dummy message"
    buildRemainingTime: @buildRemainingTime
  buildRemainingTime: (remainingTime, sprint) ->

    isValid = (key) ->

      date = new Date(key)
      sprintStart = new Date(sprint.start)

      sprintStartMs = sprintStart.getTime() # + sprintStart.getTimezoneOffset() * common.MS_TO_MIN_FACTOR
      #sprintStartMs -= sprintStartMs % common.MS_TO_DAYS_FACTOR

      sprintEnd = new Date(sprintStartMs + sprint.length * common.MS_TO_DAYS_FACTOR)
      key != 'initial' && date >= sprintStart && date < sprintEnd

    dates = (key for key of remainingTime when isValid(key)).sort()

    if dates.length == 0

      remainingTime.initial
    else

      latest = dates[dates.length - 1]
      remainingTime[latest]

class StoryModel extends Model

  type: 'story'
  constructor: (tasks, @story, @sprint) ->

  	@children = {type: 'task', objects: tasks}

class StoryViewModel extends ChildViewModel

  constructor: (@model, ractiveTemplate) ->

    @view = new StoryView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation, [id^="summary-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element
    $('#estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' 

        undoValue = @view.get 'story.color'
        @view.set 'story.color', args.value
        @model.update 'color'

          ,(data) => @view.set 'story._rev', data.rev
          ,(message) => 
          
            @view.set 'story.color', undoValue
            #TODO: error output
      when 'sprint-selector' 

        undoValue = @view.get 'story.sprint_id'
        @view.set 'story.sprint_id', args.value
        @model.update 'sprint_id'

          ,(data) => 

            @view.set 'story._rev', data.rev
            @model.getSprint data.value, (data) => 

              @view.set 'sprint', data
          ,(message) =>

            @view.set 'story.sprint_id', undoValue
            #TODO: error output
  openSelectorPopup: (ractiveEvent, id) =>

	  switch id
	    
	    when 'sprint-selector' then @model.getSprints (data) =>

	      @view.set 'sprints', data
	      @_showPopup(id)
	    else @_showPopup(id)
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'story_remove'

        @model.removeStory @model._id, (=>), (message) => @showError message
      when 'task_add' 

        @model.createTask @model.get('_id')
          ,(data) => 

            @model.children.objects.push data
            $("#summary-#{data._id}, #description-#{data._id}").each (index, element) => @_setConfirmedValue element
          ,(message) => 

            @showError message
      when 'task_open' then window.location.href = "/task/#{ractiveEvent.context._id}"
      when 'task_remove' 

        @onConfirm = => 

          @model.removeTask ractiveEvent.context
            , (id) => 

              @view.get('children').splice ractiveEvent.index.i, 1
            ,(message) => 

              @showError message
        @showConfirm common.constants.en_US.CONFIRM_TASK_REMOVAL ractiveEvent.context.summary
      when 'confirm_confirm' then @onConfirm()