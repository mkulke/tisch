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

    tasks: @model.tasks
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    sprints: [@model.sprint]
    error_message: "Dummy message"

class StoryModel extends Model

  type: 'story'
  constructor: (@tasks, @story, @sprint) ->

class StoryViewModel extends ViewModel

  type: 'story'
  constructor: (@model, ractiveTemplate) ->

    super()

    @view = new StoryView ractiveTemplate, @ractiveHandlers, @model
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation').each (index, element) => $(element).data 'confirmed_value', @view.get("story.#{this.id}")
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
  openSelectorPopup: (ractiveEvent, id) =>

	  switch id
	    
	    when 'sprint-selector' then @model.getSprints (data) =>

	      @view.set 'sprints', data
	      @_showPopup(id)
	    else @_showPopup(id)
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'story_remove' then @_showError 'Move along. This functionality is not implemented yet.'
      when 'task_add' then @_showError 'Move along. This functionality is not implemented yet.'  