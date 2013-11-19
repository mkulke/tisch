class IndexSocketIO extends SocketIO

class IndexModel extends Model

  constructor: (sprints) ->

  	@children = {type: 'sprint', objects: sprints}

class IndexViewModel extends ChildViewModel

  constructor: (@model) ->

    @common = common

    sprints = _.map @model.children.objects, (sprint) ->

      _id: ko.observable sprint._id
      start: ko.observable sprint.start
      length: ko.observable sprint.length
      title: ko.observable sprint.title
      description: ko.observable sprint.description
      color: ko.observable sprint.color

    @sprints = ko.observableArray sprints
    @formatStart = (sprint) ->

      moment(sprint.start()).format(common.DATE_DISPLAY_FORMAT)
    @formatEnd = (sprint) ->

      moment(sprint.start()).add('days', sprint.length()).format(common.DATE_DISPLAY_FORMAT)
    @sprintUrl = (sprint) ->

      '/sprint/' + sprint._id()

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