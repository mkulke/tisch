class StorySocketIO extends SocketIO

  messageHandler: (data) =>

    if data.message == 'update'
        
      #TODO: tasks
      for item in ['story', 'sprint'] when data.recipient == @model[item]._id

        @view.set "#{item}._rev", data.data.rev
        @view.set "#{item}.#{data.data.key}", data.data.value
        switch data.data.key

          when 'sprint_id' then @model.getSprint data.data.value, (data) => @view.set 'sprint', data

class StoryView extends View

  _buildRactiveData: =>

    children: @model.children.objects
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    sprints: [@model.sprint]
    sort: @_sortTasks
    error_message: "Dummy message"
    confirm_message: "Dummy message"

  ###_setRactiveObservers: =>

    @ractive.observe "children", (newValue, oldValue) -> 

      console.log "changed!"
    , {init: false}###
class StoryModel extends Model

  type: 'story'
  constructor: (tasks, @story, @sprint) ->

  	@children = {type: 'task', objects: tasks}
class StoryViewModel extends ViewModel

  constructor: (@model, ractiveTemplate) ->

    super()

    @view = new StoryView ractiveTemplate, @ractiveHandlers, @model
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation, [id^="summary-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element
    $('#estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    $('ul#well').sortable

    	tolerance: 'pointer'
    	containment: 'ul#well'
    	handle: '.header'
    $('ul#well').on 'sortstart', (event, ui) => 

      originalIndex = ui.item.index()
      $('ul#well').bind 'sortstop', (event, ui) =>

        index = ui.item.index()
        @_handleSortstop originalIndex, index
        $(this).unbind(event)

    @_initPopupSelectors()
  _sortByPriority: (a, b) ->

      a.priority > b.priority ? -1 : 1
  _calculatePriority: (originalIndex, index) =>

    objects = @model.children.objects.slice()
    object = objects[originalIndex]
    objects.splice(originalIndex, 1);
    objects.splice(index, 0, object)

    if index == 0 then prevPrio = 0
    else prevPrio = objects[index - 1].priority

    last = objects.length - 1
    if index == last 

      Math.ceil objects[index - 1].priority + 1
    else

      nextPrio = objects[index + 1].priority
      (nextPrio - prevPrio) / 2 + prevPrio
  _handleSortstop: (originalIndex, index) => 

    priority = @_calculatePriority originalIndex, index
    undoValue = @model.children.objects[originalIndex].priority
    @model.children.objects[originalIndex].priority = priority
    @model.updateChild originalIndex, 'priority'

      ,(data) =>

        @model.children.objects[originalIndex]._rev = data.rev
        @view.update()
      ,(message) =>

        @model.children.objects[originalIndex].priority = undoValue
        #TODO: show Error

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
            @view.ractive.update()
            $("#summary-#{data._id}, #description-#{data._id}").each (index, element) => @_setConfirmedValue element
          ,(message) => 

            @showError message
      when 'task_open' then window.location.href = "/task/#{ractiveEvent.context._id}"
      when 'task_remove' 

        @onConfirm = => 

          @model.removeTask ractiveEvent.context
            , (id) => 

              @model.children.objects.splice ractiveEvent.index.i, 1
              @view.ractive.update()
            ,(message) => 

              @showError message
        @showConfirm "You want to remove a task with summary #{ractiveEvent.context.summary}. This is not implemented yet."
      when 'confirm_confirm' then @onConfirm()

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