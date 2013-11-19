class IndexSocketIO extends SocketIO

  messageHandler: (data) =>

###class IndexView extends View

  _buildRactiveData: =>

    children: @model.children.objects
    COLORS: common.COLORS
    constants: common.constants
    error_message: "Dummy message"
    confirm_message: "Dummy message"
    format_date: (displayDate) -> 

      moment(displayDate).format(common.DATE_DISPLAY_FORMAT)
    calculate_end_date: (start, length) ->

      startDate = new Date(start)
      new Date(startDate.getTime() + (length * common.MS_TO_DAYS_FACTOR))###

class IndexModel extends Model

  constructor: (sprints) ->

  	@children = {type: 'sprint', objects: sprints}

class IndexViewModel extends ChildViewModel

  constructor: (@model) ->

    @common = common

    @sprints = ko.observableArray @model.children.objects
    @formatStart = (sprint) ->

      moment(sprint.start).format(common.DATE_DISPLAY_FORMAT)
    @formatEnd = (sprint) ->

      moment(sprint.start).add('days', sprint.length).format(common.DATE_DISPLAY_FORMAT)

    ###@view = new IndexView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new IndexSocketIO @view, @model

    $('#title, #description, [id^="title-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'sprint_add' 

        @model.createSprint (data) => 

            @model.children.objects.push data
            $("#summary-#{data._id}, #description-#{data._id}").each (index, element) => @_setConfirmedValue element
          ,(message) => 

            @showError message
      when 'sprint_open' then window.location.href = "/sprint/#{ractiveEvent.context._id}"
      when 'sprint_remove'
        @onConfirm = => 

          @model.removeSprint ractiveEvent.context
            , (id) => 

              @view.get('children').splice ractiveEvent.index.i, 1
            ,(message) => 

              @showError message
        @showConfirm common.constants.en_US.CONFIRM_SPRINT_REMOVAL ractiveEvent.context.title
      when 'confirm_confirm' then @onConfirm()###