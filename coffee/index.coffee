class IndexModel extends Model

  constructor: (@sprints) ->

class IndexViewModel extends ParentViewModel

  _createObservablesObject: (sprint) =>

    updateModel = partial(@_updateModel, 'sprint')

    _id: sprint._id
    start: ko.observable sprint.start
    length: ko.observable sprint.length
    title: @_createThrottledObservable sprint, 'title', updateModel
    description: @_createThrottledObservable sprint, 'description', updateModel
    color: ko.observable sprint.color
    _url: '/sprint/' + sprint._id
    _js: sprint

  constructor: (@model) ->

    super @model

    # confirmation dialog specific

    @confirmMessage = ko.observable()
    @cancel = =>

      @modal null
    @confirm = ->

    # sprints

    # TODO: sort on start changes

    @sprints = ko.observableArray _.map @model.sprints, @_createObservablesObject
    
    @formatStart = (sprint) ->

      moment(sprint.start()).format(common.DATE_DISPLAY_FORMAT)
    @formatEnd = (sprint) ->

      moment(sprint.start()).add('days', sprint.length() - 1).format(common.DATE_DISPLAY_FORMAT)

    # button handlers

    showErrorDialog = (message) =>

      @modal 'error-dialog'
      @errorMessage message

    @addSprint = =>

      # TODO: sort correctly
      onSuccess = (data) =>

        @sprints.push @_createObservablesObject data.new

      @model.createSprint onSuccess, showErrorDialog

    @removeSprint = (sprintObservable) =>

      @modal 'confirm-dialog'
      # TODO: i18n
      @confirmMessage 'Are you sure? The sprint, its stories and the tasks assigned to them will be permanently removed.'
      @confirm = =>

        @modal null
        sprint = sprintObservable._js
        @model.removeSprint sprint

          , =>

            @sprints.remove (item) =>

              item._id == sprint._id
          , showErrorDialog