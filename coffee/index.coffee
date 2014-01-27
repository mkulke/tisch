class IndexModel extends Model

  constructor: (@sprints) ->

class IndexViewModel extends ViewModel

  _addChild: (array, data) =>
    
    observables = @_createObservables data.new
    observables.readonly.start.subscribe partial(@_sortByStart, array)
    array.push observables

  _createObservables: (sprint) =>

    updateModel = partial @_updateModel, 'sprint'
    createObservable = partial @_createObservable, updateModel, sprint

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

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

  formatStart: (sprint) ->

    moment(sprint.readonly.start()).format(common.DATE_DISPLAY_FORMAT)
  formatEnd: (sprint) ->

    moment(sprint.readonly.start()).add('days', sprint.readonly.length() - 1).format(common.DATE_DISPLAY_FORMAT)

  _sortByStart: (array) ->

    array.sort (a, b) ->

      moment(a.readonly.start()).unix() - moment(b.readonly.start()).unix()

  addSprint: =>

    # TODO: sort correctly
    onSuccess = (data) =>

      observables = @_createObservables data.new
      @sprints.push observables
      observables.readonly.start.subscribe partial(@_sortByStart, @sprints)

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

    _.bindAll @, _.functions(parentMixin)...

    @sprints = ko.observableArray _.map @model.sprints, @_createObservables
    _.chain(@sprints()).pluck('readonly').pluck('start').invoke('subscribe', partial(@_sortByStart, @sprints))

    # rt specific initializations

    wires = _.chain(@sprints()).map(partial(@_createChildWires, @sprints)).flatten().value()
    wires.push @_createAddWire('index', @sprints)

    socket = new SocketIO()
    socket.connect (sessionid) =>

      @sprints.subscribe partial(@_adjustChildWires, socket, @sprints, wires), null, 'arrayChange'
      @model.sessionid = sessionid
      socket.registerWires wires

_.extend IndexViewModel.prototype, parentMixin
