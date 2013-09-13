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
    error_message: "Dummy message"
    confirm_message: "Dummy message"

class StoryModel extends Model

  type: 'story'
  constructor: (tasks, @story, @sprint) ->

  	@children = {type: 'task', objects: tasks}
class StoryViewModel extends ViewModel

  constructor: (@model, ractiveTemplate) ->

    super()

    @view = new StoryView ractiveTemplate, @ractiveHandlers, @model
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation').each (index, element) => $(element).data 'confirmed_value', @view.get("story.#{element.id}")
    $('[id^="summary-"]').each (index, element) => $(element).data 'confirmed_value', @view.get("children[#{index}].summary")
    $('[id^="description-"]').each (index, element) => $(element).data 'confirmed_value', @view.get("children[#{index}].description")
    $('#estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    $('ul#well').sortable

    	tolerance: 'pointer'
    	containment: 'ul#well'
    	handle: '.header'

    @_initPopupSelectors()
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' then @model.requestUpdate 'color', args.value, (data) => 

        @view.set 'story._rev', data.rev
        @view.set 'story.color', data.value
      when 'sprint-selector' 

        @model.requestUpdate 'sprint_id', args.value, (data) => 

          @view.set 'story._rev', data.rev
          @view.set 'story.stprint_id', data.value
          @model.getSprint data.value, (data) => 

            @view.set 'sprint', data
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

      when 'story_remove' then @showError 'Move along. This functionality is not implemented yet.'
      when 'task_add' then @showError 'Move along. This functionality is not implemented yet.'
      when 'task_open' then window.location.href = "/task/#{ractiveEvent.context._id}"
      when 'task_remove' 

        @onConfirm = => @model.children.objects.splice ractiveEvent.index.i, 1
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

        @view.set "#{type}._rev", data.rev
        @view.set "#{type}.#{key}", data.value
        if $(node).data('confirmed_value')? then @_setConfirmedValue node
      errorCb = => 

      	if childIndex? then keypath = "children[#{childIndex}].#{key}"
      	else keypath = "#{type}.#{key}"      	
      	@view.set keypath, $(node).data('confirmed_value')

      if !@_isConfirmedValue(node) 

      	if childIndex? then @model.requestChildUpdate childIndex, key, value, successCb, errorCb
      	else @model.requestUpdate key, value, successCb, errorCb