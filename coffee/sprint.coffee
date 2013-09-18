class SprintSocketIO extends SocketIO

  messageHandler: (data) =>

class SprintView extends View

  _buildRactiveData: =>

    children: @model.children.objects
    sprint: @model.sprint
    COLORS: common.COLORS
    constants: common.constants
    error_message: "Dummy message"
    confirm_message: "Dummy message"
    format_date: (displayDate) -> 

      $.datepicker.formatDate common.DATE_DISPLAY_FORMAT, new Date(displayDate)

class SprintModel extends Model

  type: 'sprint'
  constructor: (stories, @sprint) ->

  	@children = {type: 'story', objects: stories}

class SprintViewModel extends ChildViewModel

  constructor: (@model, ractiveTemplate) ->

    @view = new SprintView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new SprintSocketIO @view, @model

    $('#title, #description, [id^="title-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element

    @_initPopupSelectors()
    @_initDatePickers()
  _selectDate: (dateText, inst) =>

    dateSelector = super(dateText, inst)
    newDate = new Date(dateText)
    undoValue = dateSelector.data 'date'
    @view.set 'sprint.start', newDate.toString()
    @model.update 'start'

      ,(data) => 

        @view.set 'sprint._rev', data.rev
        dateSelector.data 'date', data.value
      ,(message) =>

        @view.set 'sprint.start', undoValue
        #TODO show error
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
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'sprint_remove'

        @model.removeSprint @model._id, (=>), (message) => @showError message
      when 'story_add' 

        @model.createStory @model.get('_id')
          ,(data) => 

            @model.children.objects.push data
            $("#title-#{data._id}, #description-#{data._id}").each (index, element) => @_setConfirmedValue element
          ,(message) => 

            @showError message
      when 'story_open' then window.location.href = "/story/#{ractiveEvent.context._id}"
      when 'story_remove' 

        @onConfirm = => 

          @model.removeStory ractiveEvent.context
            , (id) => 

              @model.children.objects.splice ractiveEvent.index.i, 1
            ,(message) => 

              @showError message
        @showConfirm common.constants.en_US.CONFIRM_STORY_REMOVAL ractiveEvent.context.title
      when 'confirm_confirm' then @onConfirm()