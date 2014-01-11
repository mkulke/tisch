class IndexModel extends Model

  constructor: (@sprints) ->

class IndexViewModel extends ParentViewModel

  _createObservables: (sprint) =>

    updateModel = partial @_updateModel, 'sprint'
    createObservable_ = partial @_createObservable3, updateModel, sprint

    id: sprint._id
    url: '/sprint/' + sprint._id
    js: sprint
    readonly:

      color: ko.observable sprint.color
      start: ko.observable sprint.start
      length: ko.observable sprint.length  
    writable: _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}

  formatStart: (sprint) ->

    moment(sprint.readonly.start()).format(common.DATE_DISPLAY_FORMAT)
  formatEnd: (sprint) ->

    moment(sprint.readonly.start()).add('days', sprint.readonly.length() - 1).format(common.DATE_DISPLAY_FORMAT)

  addSprint: =>

    # TODO: sort correctly
    onSuccess = (data) =>

      @sprints.push @_createObservables data.new

    @model.createSprint onSuccess, @showErrorDialog

  removeSprint: (observables) =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The sprint, its stories and the tasks assigned to them will be permanently removed.', =>

      sprint = observables.js
      @model.removeSprint sprint, =>

        @sprints.remove (item) =>

          item.id == sprint._id
        , @showErrorDialog

  constructor: (@model) ->

    super @model

    @sprints = ko.observableArray _.map @model.sprints, @_createObservables
    # TODO: sort on start changes

    # rt specific initializations

    notifications = _.chain(@sprints()).map(partial(@_createChildNotifications, @sprints)).flatten().value()

    socket = new SocketIO()
    socket.connect (sessionid) =>

      @sprints.subscribe partial(@_adjustNotifications, socket, @sprints, notifications), null, 'arrayChange'
      @model.sessionid = sessionid
      socket.registerNotifications notifications