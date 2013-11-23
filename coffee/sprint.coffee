class SprintSocketIO extends SocketIO

###class SprintView extends View

  _buildRactiveData: =>

    children: @model.children.objects
    sprint: @model.sprint
    COLORS: common.COLORS
    constants: common.constants
    error_message: "Dummy message"
    confirm_message: "Dummy message"
    remaining_time: @model.calculations.remaining_time
    format_date: (displayDate) -> 

      moment(displayDate).format(common.DATE_DISPLAY_FORMAT)
    calculate_end_date: (start, length) ->

      startDate = new Date(start)
      new Date(startDate.getTime() + (length * common.MS_TO_DAYS_FACTOR))###

class SprintModel extends Model

  type: 'sprint'
  constructor: (stories, @sprint, @calculations) ->

  	@children = {type: 'story', objects: stories}

  calculatePriority: (objects, originalIndex, index) =>

    if index == 0 then prevPrio = 0
    else prevPrio = objects[index - 1].priority()

    last = objects.length - 1
    if index == last 

      Math.ceil objects[index - 1].priority() + 1
    else

      nextPrio = objects[index + 1].priority()
      (nextPrio - prevPrio) / 2 + prevPrio

class SprintViewModel extends ViewModel

  _updateSprintModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'sprint', property, value
  _updateStoryModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'story', property, value

  constructor: (@model) ->

    super(@model)

    # set global options for jquery ui sortable

    ko.bindingHandlers.sortable.options = 

      tolerance: 'pointer'
      delay: 150
      cursor: 'move'
      containment: 'ul#well'
      handle: '.header'
    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @model.calculatePriority @stories(), arg.sourceIndex, arg.targetIndex
      arg.item.priority priority

    # confirmation dialog specific

    @confirmMessage = ko.observable()
    @cancel = =>

      @modal null
    @confirm = ->

    # title

    @title = @_createThrottledObservable @model.sprint, 'title', @_updateSprintModel

    # description

    @description = @_createThrottledObservable @model.sprint, 'description', @_updateSprintModel

    # color

    @color = @_createObservable @model.sprint, 'color', @_updateSprintModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # start

    @showStartDatePicker = => 

      @modal 'start-selector'
    @start = @_createObservable @model.sprint, 'start', @_updateSprintModel
    @startDate = ko.computed

      read: =>

        new Date(@start())
      write: (value) =>

        # the datepicker binding returns a xxxx-xx-xx string, we need a Date, tho.
        @start new moment(value).toDate()
      owner: @
    @startFormatted = ko.computed =>

      moment(@start()).format(common.DATE_DISPLAY_FORMAT)

    # length

    @showLengthDatePicker = => 

      @modal 'length-selector'
    @length = @_createObservable @model.sprint, 'length', @_updateSprintModel
    @lengthDate = ko.computed

      read: =>

        moment(@start()).add('days', @length() - 1).toDate()
      write: (value) =>

        start = moment @start()
        # since @start() as 'XXXX-XX-XXT00:00:00.000Z' is parsed w/o timezone offset, and value
        # is 'XXXX-XX-XX' has the timezone offset, we need to use moment.utc here to calculate
        # the delta here.
        end = moment.utc value
        @length moment.duration(end - start).days() + 1
    @endFormatted = ko.computed =>

      moment(@lengthDate()).format(common.DATE_DISPLAY_FORMAT)

    # calculations

    remainingTimeCalculations = ko.observable @model.calculations.remaining_time

    # stories

    createObservablesObject = (story) =>

      _id: story._id
      title: @_createObservable story, 'title', @_updateStoryModel
      description: @_createObservable story, 'description', @_updateStoryModel
      color: @_createObservable story, 'color', @_updateStoryModel
      priority: @_createObservable story, 'priority', @_updateStoryModel
      _remaining_time: ko.computed =>

        if remainingTimeCalculations()[story._id]? 

          remainingTimeCalculations()[story._id]
        else

          null
      _url: '/story/' + story._id
      _js: story

    stories = _.map @model.children.objects, createObservablesObject

    @stories = ko.observableArray stories
    @stories.subscribe (changes) =>

      for change in changes

        if change.status == 'added'

          storyObservable = @stories()[change.index]
          @model.children.objects.splice change.index, 0, storyObservable._js
        else if change.status == 'deleted'

          @model.children.objects.splice change.index, 1
    , null, 'arrayChange'

    showErrorDialog = (message) =>

      @modal 'error-dialog'
      @errorMessage message

    @addStory = =>

      @model.createStory @model.sprint._id

        , (story) => 
        
          observableObject = createObservablesObject story
          @stories.push observableObject
          # TODO: sort after push?
        , showErrorDialog

    @removeStory = (storyObservable) =>

      @modal 'confirm-dialog'
      # TODO: i18n
      @confirmMessage 'Are you sure? All the stories and tasks assigned to the sprint will be permanently removed.'
      @confirm = =>

        @modal null
        story = storyObservable._js
        @model.removeStory story

          , =>

            @stories.remove (item) =>

              item._id == story._id
          , showErrorDialog

  ###constructor: (@model, ractiveTemplate) ->

    @view = new SprintView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new SprintSocketIO @view, @model

    $('#title, #description, [id^="title-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element

    @_initPopupSelectors()
    @_initDatePickers()
    $('#length .content').datepicker 'option', 'minDate', new Date(@model.sprint.start)
  _selectDate: (dateText, inst) =>

    # TODO: unit test

    super(dateText, inst)

    dateSelector = $(inst.input).parents('.date-selector')
    newDate = new Date(dateText)
    id = dateSelector.attr('id')

    switch id

      when 'start_date'

        undoValue = @view.get 'sprint.start'
        @view.set 'sprint.start', newDate.toString()
        @model.update 'start'

          ,(data) => 

            @view.set 'sprint._rev', data.rev
            $('#length .content').datepicker 'option', 'minDate', new Date(data.value)
          ,(message) =>

            @view.set 'sprint.start', undoValue
            #TODO show error
      when 'length'
        undoValue = @view.get 'sprint.length'
        newLength = (newDate - new Date(@view.get 'sprint.start')) / common.MS_TO_DAYS_FACTOR
        @view.set 'sprint.length', newLength
        @model.update 'length'

          ,(data) =>

            @view.set 'sprint._rev', data.rev
          ,(message) =>

            @view.set 'sprint.length', undoValue
            #TODO: show error
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' 

        undoValue = @view.get 'sprint.color'
        @view.set 'sprint.color', args.value
        @model.update 'color'

          ,(data) => @view.set 'sprint._rev', data.rev
          ,(message) => 
          
            @view.set 'sprint.color', undoValue
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
      when 'confirm_confirm' then @onConfirm()###