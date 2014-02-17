class SprintModel extends Model

  _getCalculation: (calculation, storyId, successCb) =>

    # TODO: move constants

    $.ajaxq 'client',

      url: "/calculation/#{storyId}?"
      type: 'GET'
      dataType: 'json'
      data: 

        start: moment(@sprint.start).format('YYYY-MM-DD')
        end: moment(@sprint.start).add('days', @sprint.length - 1).format('YYYY-MM-DD')
        func: calculation
      success: (data, textStatus, jqXHR) ->
        
        successCb? data

  _getCalculations: (fn, storyIds, successCb) =>

    gets = []
    result = {}
    _.each storyIds, (storyId) ->

      gets.push fn storyId, (data) ->

        result[storyId] = data
    $.when.apply($, gets).then ->

      successCb? result

  type: 'sprint'
  constructor: (@stories, @sprint, @calculations) ->

    @getTimeSpent = partial @_getCalculation, 'time_spent_for_story'
    @getTimesSpent = partial @_getCalculations, @getTimeSpent
    @getRemainingTime = partial @_getCalculation, 'remaining_time_for_story'
    @getRemainingTimes = partial @_getCalculations, @getRemainingTime
    @getTaskCount = partial @_getCalculation, 'task_count_for_story'
    @getTaskCounts = partial @_getCalculations, @getTaskCount

class SprintViewModel extends ViewModel

  _createObservables: (story) =>

    updateModel = partial @_updateModel, 'story'
    createObservable = partial @_createObservable, updateModel, story

    computed =

      remaining_time: ko.computed =>

        @readonly.remainingTimeCalculations()[story._id]

    readonly = 

      color: ko.observable story.color
      sprint_id: ko.observable story.sprint_id

    writable = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'priority'}
    ], (object, property) ->

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

    observables = 

      id: story._id
      url: '/story/' + story._id
      js: story
      computed: computed
      readonly: readonly
      writable: writable

    @_setupMarkdown.call observables, writable.description
    observables

  _updateStat: (id) =>

    update = (observable, data) =>

      object = observable()
      object[id] = data
      observable.notifySubscribers object

    @model.getRemainingTime id, partial(update, @readonly.remainingTimeCalculations)
    @model.getTimeSpent id, partial(update, @readonly.timeSpentCalculations)   
    @model.getTaskCount id, partial(update, @readonly.taskCountCalculations)   

  _updateStats: =>

    ids = _.pluck(@stories(), 'id')

    @model.getRemainingTimes ids, @readonly.remainingTimeCalculations
    @model.getTimesSpent ids, @readonly.timeSpentCalculations
    @model.getTaskCounts ids, @readonly.taskCountCalculations

  _createGrandchildWires: (observables) =>

    shared = 

      handler: partial @_updateStat, observables.id
      parent_id: observables.id
    specifics = [

      method: "POST"
      properties: ['remaining_time', 'time_spent']
    ,
      method: "POST"
      properties: ["story_id"]
      handler: @_updateStats
    ,
      method: "PUT"
    ,
      method: "DELETE"
    ]
    grandchildWires = _.map(specifics, curry2(_.defaults)(shared))
    grandchildWires.concat @_createChildWires @stories, observables

  _adjustGrandchildWires: (socket, wires, changes) =>

    _.each changes, (change) =>

      if change.status == 'added'

        observables = @stories()[change.index]
        newWires = @_createGrandchildWires observables
        socket.registerWires newWires
        wires = wires.concat newWires
      else if change.status == 'deleted'

        socket.unregisterWires _.where(wires, {parent_id: change.value.id})

  showColorSelector: =>

    @modal 'color-selector'

  selectColor: (color) =>

    @modal null
    @writable.color color

  showStartDatePicker: => 

    @modal 'start-selector'

  showLengthDatePicker: => 

    @modal 'length-selector'

  addStory: =>

    @model.createStory @model.sprint._id, partial(@_addChild, @stories), @showErrorDialog
  
  removeStory: (observables) =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The story and the tasks assigned to it will be permanently removed.', =>

      story = observables.js
      @model.removeStory story, =>

        @stories.remove (item) =>

          item.id == story._id
        , @showErrorDialog

  showStats: =>

    @modal 'stats-dialog'

  closeStats: =>

    @modal null

  constructor: (@model) ->

    super(@model)

    _.bindAll @, _.functions(parentMixin)..., _.functions(sortableMixin)...

    # observables

    updateModel = partial @_updateModel, 'sprint'
    createObservable = partial @_createObservable, updateModel, @model.sprint

    @writable = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'color'}
      {name: 'start'}
      {name: 'length'}
    ], (object, property) ->

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

    @readonly =

      remainingTimeCalculations: ko.observable @model.calculations.remaining_time
      timeSpentCalculations: ko.observable @model.calculations.time_spent
      taskCountCalculations: ko.observable @model.calculations.task_count

    @computed = do =>

      sum = (observable) =>

        _.reduce(observable(), (memo, value) ->

          add memo, value
        , 0)

      lengthDate = ko.computed

        read: =>

          moment(@writable.start()).add('days', @writable.length() - 1).toDate()
        write: (value) =>

          start = moment @writable.start()
          # since @start() as 'XXXX-XX-XXT00:00:00.000Z' is parsed w/o timezone offset, and value
          # is 'XXXX-XX-XX' has the timezone offset, we need to use moment.utc here to calculate
          # the delta here.
          end = moment.utc value
          @writable.length moment.duration(end - start).days() + 1
        owner: @
      startDate: ko.computed

        read: =>

          new Date(@writable.start())
        write: (value) =>

          # the datepicker binding returns a xxxx-xx-xx string, we need a Date, tho.
          @writable.start new moment(value).toDate()
        owner: @
      startFormatted: ko.computed =>

        moment(@writable.start()).format(common.DATE_DISPLAY_FORMAT)
      endFormatted: ko.computed =>

        moment(lengthDate()).format(common.DATE_DISPLAY_FORMAT)
      lengthDate: lengthDate
      remainingTime: ko.computed partial(sum, @readonly.remainingTimeCalculations) 
      timeSpent: ko.computed partial(sum, @readonly.timeSpentCalculations)
      taskCount: ko.computed partial(sum, @readonly.taskCountCalculations)

    @writable.start.subscribe @_updateStats
    @writable.length.subscribe @_updateStats

    # stories

    @stories = ko.observableArray _.map @model.stories, @_createObservables
    _.chain(@stories()).pluck('writable').pluck('priority').invoke('subscribe', partial(@_sortByPriority, @stories))
    @_subscribeToAssignmentChanges @stories, 'sprint_id'
    @_setupSortable @stories()

    # markdown

    @_setupMarkdown @writable.description

    # rt specific initializations

    wires = []
    observables = _.extend {}, @writable, @readonly

    wires.push @_createAssignmentWire(@model.sprint._id, @stories, 'sprint_id', @model.getStory)
    wires.push @_createUpdateWire(@model.sprint, observables)
    wires.push @_createAddWire(@model.sprint._id, @stories)
    wires = wires.concat _.chain(@stories()).map(partial(@_createChildWires, @stories)).flatten().value()
      ,_.chain(@stories()).map(@_createGrandchildWires).flatten().value()

    socket = new SocketIO()
    socket.connect (sessionid) =>

      @stories.subscribe partial(@_adjustChildWires, socket, @stories, wires), null, 'arrayChange'
      @stories.subscribe partial(@_adjustGrandchildWires, socket, wires), null, 'arrayChange'
      @model.sessionid = sessionid
      socket.registerWires wires

_.extend SprintViewModel.prototype, parentMixin
_.extend SprintViewModel.prototype, sortableMixin
_.extend SprintViewModel.prototype, markdownMixin