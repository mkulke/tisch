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

  _getCalculations: (promiseFn, storyIds, successCb) =>

    result = []
    gets = _.map storyIds, (storyId) ->

      promiseFn storyId, (data) ->

        if data?

          result.push [storyId, data]
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

        belongsToStory = _.compose(partial(_.isEqual, story._id), _.first)
        calculation = _.chain(@readonly.remainingTimeCalculations()).find(belongsToStory).last().value()
        @model._mostRecentValue(calculation)

    readonly = 

      color: ko.observable story.color
      sprint_id: ko.observable story.sprint_id
      estimation: ko.observable story.estimation

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

  _refreshChart: =>

    buildObj = (date, value) ->

      {date: moment(date).format('YYYY-MM-DD'), value: value}

    # TODO: chart render issues when sprint range is modified.
    @chart.refresh 

      'remaining-time': @computed.remainingTimeChartData()
      reference: [

        buildObj(@computed.startDate(), @computed.allStoriesEstimation())
        buildObj(@computed.lengthDate(), 0)
      ]

  _updateStat: (id) =>

    update = (observable, data) ->

      belongsToStory = _.compose(partial(_.isEqual, id), _.first)
      storyRow = _.find(observable(), belongsToStory)
      if storyRow? 

        storyRow[1] = data
      else

        observable().push [id, data]
      observable.notifySubscribers observable()

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

  _extractDatesFromCalculations: (calculations) ->

    toPairs = curry2(at)(1)
    toDates = curry2(_.map)(_.first)
    _.union(_.chain(calculations).map(toPairs).reject(_.isEmpty).map(toDates).value()...)

  _toChartData: (pair) ->

    {date: _.first(pair), value: _.last(pair)} 

  _createTimeSpentChartData: (allCalculations) =>

    toPairs = curry2(at)(1)
    valueForDate = (storyCalculations, date) ->

      pairs = toPairs storyCalculations

      byMatchingDate = _.compose partial(equals, date), _.first
      pair = _.find pairs, byMatchingDate
      _.last(pair) || 0

    allDates = @_extractDatesFromCalculations allCalculations
    allValues = _.map allDates, (date) ->

      sum _.map(allCalculations, curry2(valueForDate)(date))

    zippedPairs = _.zip(allDates, allValues)
    # prepend with 0 if necessary
    startDate = moment(@writable.start()).format('YYYY-MM-DD')
    zippedPairs = [[startDate, 0]].concat(zippedPairs) unless _.contains(allDates, startDate) || allDates.length == 0
    _.map zippedPairs, @_toChartData

  _createRemainingTimeChartData: (allCalculations, allEstimations) =>

    toPairs = curry2(at)(1)
    findEstimation = (id) ->

      pair = _.find(allEstimations, _.compose(partial(equals, id), _.first))
      _.last(pair) || 0
    toDates = curry2(_.map)(_.first)

    valueForDate = (storyCalculations, date) ->

      pairs = toPairs storyCalculations
      dates = toDates pairs 

      dateMatcher = (memo, value) ->

        if value <= date && date != 'initial' then value else memo
      closestDate = _.reduce(_.rest(dates), dateMatcher, 'initial')

      byClosestDate = _.compose partial(equals, closestDate), _.first
      
      calculation = _.find pairs, byClosestDate
      _.last(calculation) || findEstimation(_.first(storyCalculations))

    # Extract all unique dates in the calculations
    allDates = @_extractDatesFromCalculations allCalculations
    # get date-value for every date found in all story calculations
    allValues = _.map allDates, (date) ->

      sum _.map(allCalculations, curry2(valueForDate)(date))

    # move initial to the front, if necessary
    startDate = moment(@writable.start()).format('YYYY-MM-DD')
    if allDates.length > 0

      if allDates[1] != startDate

        allDates[0] = startDate
      else

        allDates = _.rest allDates
        allValues[1] += allValues[0]
        allValues = _.rest allValues
    zippedPairs = _.zip(allDates, allValues)
    _.map zippedPairs, @_toChartData

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

      mostRecentValues = curry2(_.map)(_.compose(@model._mostRecentValue, _.last))
      accumulatedValues = curry2(_.map)(_.compose(sum, curry2(_.map)(_.last), _.last))
      normalize = curry2(_.map)((value) ->

        value || 0
      )

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
      remainingTime: ko.computed _.compose(sum, normalize, mostRecentValues, @readonly.remainingTimeCalculations)
      timeSpent: ko.computed _.compose(sum, accumulatedValues, @readonly.timeSpentCalculations)
      taskCount: ko.computed _.compose(sum, curry2(_.map)(_.last), @readonly.taskCountCalculations)

    @writable.start.subscribe @_updateStats
    @writable.length.subscribe @_updateStats

    # stories

    @stories = ko.observableArray _.map @model.stories, @_createObservables
    _.chain(@stories()).pluck('writable').pluck('priority').invoke('subscribe', partial(@_sortByPriority, @stories))
    @_subscribeToAssignmentChanges @stories, 'sprint_id'
    @stories.subscribe @_updateStats, null, 'arrayChange'
    @computed.allStoriesEstimation = ko.computed _.compose(sum, curry2(_.invoke)('estimation'), curry2(_.pluck)('readonly'), @stories)
    @computed.remainingTimeChartData = ko.computed => 

      calculations = @readonly.remainingTimeCalculations()
      ids = calculations.map(_.first)
      estimations = _.zip(ids, _.chain(@stories()).pluck('readonly').invoke('estimation').value())
      @_createRemainingTimeChartData calculations, estimations

    @_setupSortable @stories()

    # markdown

    @_setupMarkdown @writable.description

    # chart

    @chart = new Chart ['reference', 'remaining-time', 'time-spent']
    @_refreshChart()

    @computed.remainingTimeChartData.subscribe @_refreshChart
    @computed.allStoriesEstimation.subscribe @_refreshChart
    @computed.startDate.subscribe @_refreshChart
    @computed.lengthDate.subscribe @_refreshChart

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