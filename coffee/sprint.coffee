class SprintSocketIO extends SocketIO

  messageHandler: (data) =>

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

class SprintViewModel extends ViewModel

  constructor: (@model) ->

    super(@model)

    # title

    @title = @_createThrottledObservable @model.sprint, 'title', @_updateModel

    # description

    @description = @_createThrottledObservable @model.sprint, 'description', @_updateModel

    # color

    @color = @_createObservable @model.sprint, 'color', @_updateModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # start

    @showStartDatePicker = => 

      @modal 'start-selector'
    @start = @_createObservable @model.sprint, 'start', @_updateModel
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
    @length = @_createObservable @model.sprint, 'length', @_updateModel
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