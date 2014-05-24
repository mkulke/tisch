class StoryModel extends Model

  type: 'story'
  constructor: (@tasks, @story, @sprint) ->

  buildTimeSpent: (timeSpent, range) ->

    spentTimes = (value for key, value of timeSpent when range.start <= key <= range.end)
    spentTimes.reduce (count, spentTime) ->

      count + spentTime
    ,0

  buildRemainingTime: (remainingTime, range) ->

    withinRange = (date) ->

      range.start <= date <= range.end

    lastDate = _.chain(remainingTime).keys().filter(withinRange).sort().last().value()
    if lastDate
      remainingTime[lastDate]
    else
      # TODO: make this configurable
      1

  _collectIndices: (range, indices, property) =>

    inRange = (value) ->

      range.start <= value <= range.end

    _.chain(property).keys().filter(inRange).union(indices).sort().value()    

  buildTimeSpentChartData: (timesSpent, range) ->

    # This functions collect the dates from all time_spent objects while discarding 
    # the out-of-sprint values. Then for every found date all task values for that
    # date are accumulated. Finally, if no 1st sprint day value was found and it is
    # not empty, it is prepended with a zero value.

    add = (index, memo, timeSpent) ->

      time = timeSpent[index]
      if time? 

        memo + time
      else

        memo

    toD3 = (index) ->

      {date: index, value: _.reduce timesSpent, partial(add, index), 0}

    nullValue = (object) ->

      object.value == 0

    cumulate = (data, datum) ->

      if data.length > 0

        clone = _.clone(datum)
        clone.value += _.last(data).value
        data.push clone
      else

        data.push datum
      data

    prepend = (data) ->

      if !_.isEmpty(data) && _.first(data).date != range.start

        data.unshift {date: range.start, value: 0}

    _.chain(timesSpent).reduce(partial(@_collectIndices, range), []).map(toD3).reject(nullValue).reduce(cumulate, []).tap(prepend).value()

  buildRemainingTimeChartData: (estimation, remainingTimes, range) ->

    # This functions collect the dates from all remaining_time objects while discarding 
    # the out-of-sprint values. Then for every found date a value is fetched/calculated
    # for each task, the results are accumulated. Finally, if no 1st sprint day value was 
    # found, it is prepended with the stories estimation. 

    closestDate = (date, remainingTime) ->

      equalOrOlder = (matchDate) ->

        range.start <= matchDate <= date

      _.chain(remainingTime).keys().filter(equalOrOlder).sort().last().value()

    withinRange = (date) ->

      range.start <= date <= range.end

    dates = _.chain(remainingTimes)
      .map(_.keys)
      .flatten()
      .unique()
      .filter(withinRange)
      .union([range.start])
      .sort()
      .value()
    
    toD3 = (date) ->

      value = _.reduce(remainingTimes, (memo, remainingTime) ->

        memo += if _.has(remainingTime, date)
          remainingTime[date]
        else
          # tasks without a defined rt have one. TODO: make configurable
          closest = closestDate(date, remainingTime)
          if closest?
            remainingTime[closest]
          else
            1
      , 0)
      date: date, value: if remainingTimes.length > 0
        value
      else
        estimation
    _.map dates, toD3

class StoryViewModel extends ViewModel

  _createObservables: (task) =>

    updateModel = partial @_updateModel, 'task'
    createObservable = partial @_createObservable, updateModel, task
    remainingTime = ko.observable task.remaining_time

    writable = _.reduce [

      {name: 'summary', throttled: true}
      {name: 'description', throttled: true}
      {name: 'priority'}
    ], (object, property) ->

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

    readonly =

      story_id: ko.observable task.story_id
      color: ko.observable task.color
      remaining_time: remainingTime
      time_spent: ko.observable task.time_spent  

    computed =

      remaining_time: ko.computed =>

        @model.buildRemainingTime remainingTime(), @sprint.computed.range()

    observables =

      id: task._id
      url: '/task/' + task._id
      js: task
      computed: computed
      readonly: readonly
      writable: writable

    @_setupMarkdown.call observables, writable.description   
    observables

  _replaceSprint: (sprint) =>

    # cannot use each b/c of length & underscore
    object = _.pick sprint, 'title', 'start', 'length'
    for key, value of object

      @sprint.readonly[key] value

  showColorSelector: =>

    @modal 'color-selector'
  
  selectColor: (color) =>

    @modal null
    @writable.color color

  sprints: ko.observable()

  showSprintSelector: => 

    @model.getSprints null, (sprints) =>

      @sprints _.map sprints, (sprint) ->

        {id: sprint._id, label: sprint.title}
      @modal 'sprint-selector'
    
  selectSprint: (selected) =>

    @modal null
    @model.getSprint selected.id, (sprint) =>

      @writable.sprint_id sprint._id
      @_replaceSprint sprint
    , @_showError
  
  addTask: =>

    @model.createTask @model.story._id, partial(@_addChild, @tasks), @showErrorDialog

  removeTask: (observables) =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The task will be permanently removed.', =>

      task = observables.js
      @model.removeTask task, =>

        @tasks.remove (item) =>

          item.id == task._id
        , @showErrorDialog

  remove: =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The story and its tasks will be permanently removed.', =>

      @model.removeStory @model.story, => 

        window.location.replace '/sprint/' + @sprint.computed.id()
      , @showErrorDialog

  showStats: =>

    @modal 'stats-dialog'

  closeStats: =>

    @modal null

  _refreshChart: =>

    # TODO: chart render issues when sprint range is modified.
    @chart.refresh 

      'remaining-time': @stats.computed.remainingTimeChartData()
      'time-spent': @stats.computed.timeSpentChartData()
      reference: [

        {date: @sprint.computed.range().start, value: @writable.estimation()}
        {date: moment(@sprint.computed.range().end).format(common.DATE_DB_FORMAT), value: 0}
      ]

  constructor: (@model) ->

    super(@model)

    # explicitely do not bind the markdown mixin fns, as call() for childs in _createObservables 
    # will fail. it's questionably wheter binding is needed for those fns...
    _.bindAll @, _.functions(parentMixin)..., _.functions(sortableMixin)...

    # breadcrumbs

    @breadcrumbs =

      sprint: 

        id: @model.sprint._id
        readonly:

          title: ko.observable @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    # observables

    updateModel = partial(@_updateModel, 'story');
    createObservable = partial @_createObservable, updateModel, @model.story

    @writable = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'color'}
      {name: 'sprint_id'}
      {name: 'estimation', throttled: true, time: true}
    ], (object, property) ->

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

    # sprint specific stuff

    @sprint = do =>

      start = ko.observable @model.sprint.start
      length = ko.observable @model.sprint.length

      computed:

        id: ko.computed =>

          @writable.sprint_id()
        range: ko.computed =>

          @model.buildSprintRange start(), length()
      readonly:

        title: ko.observable @model.sprint.title
        start: start
        length: length

    # tasks

    @tasks = ko.observableArray _.map @model.tasks, @_createObservables
    _.chain(@tasks()).pluck('writable').pluck('priority').invoke('subscribe', partial(@_sortByPriority, @tasks))
    @_subscribeToAssignmentChanges @tasks, 'story_id'
    @_setupSortable @tasks()

    # stats

    @stats = 

      computed:

        allRemainingTime: ko.computed =>

          _.reduce @tasks(), (count, task) =>

            count + @model.buildRemainingTime task.readonly.remaining_time(), @sprint.computed.range()
          , 0      
        allTimeSpent: ko.computed =>

          _.reduce @tasks(), (count, task) => 

            count + @model.buildTimeSpent task.readonly.time_spent(), @sprint.computed.range()
          ,0
        remainingTimeChartData: ko.computed =>

          remainingTimes = _.chain(@tasks()).pluck('readonly').pluck('remaining_time').invoke('call').value()
          @model.buildRemainingTimeChartData @writable.estimation(), remainingTimes, @sprint.computed.range()

        timeSpentChartData: ko.computed =>

          timesSpent = _.chain(@tasks()).pluck('readonly').pluck('time_spent').invoke('call').value()
          @model.buildTimeSpentChartData timesSpent, @sprint.computed.range()

    @chart = new Chart ['reference', 'remaining-time', 'time-spent']
    @_refreshChart()

    @stats.computed.remainingTimeChartData.subscribe (value) =>

      @_refreshChart()
    @stats.computed.timeSpentChartData.subscribe (value) =>

      @_refreshChart()      

    # markdown

    @_setupMarkdown @writable.description

    # realtime specific initializations

    wires = []
    observables = _.extend {}, @writable, @readonly
    wires.push @_createAssignmentWire(@model.story._id, @tasks, 'story_id', @model.getTask)
    wires.push @_createUpdateWire(@model.story, observables)
    wires.push @_createAddWire(@model.story._id, @tasks)
    wires.push sprintWire = @_createUpdateWire(@model.sprint, @sprint.readonly)
    wires.push @_createUpdateWire(_.pick(@model.sprint, '_id'), @breadcrumbs.sprint.readonly)
    wires = wires.concat _.chain(@tasks()).map(partial(@_createChildWires, @tasks)).flatten().value()
    
    socket = new SocketIO()
    socket.connect (sessionid) =>

      @tasks.subscribe partial(@_adjustChildWires, socket, @tasks, wires), null, 'arrayChange'

      @writable.sprint_id.subscribe (value) =>

        @model.getSprint value, @_replaceSprint
        socket.unregisterWires sprintWire
        sprintWire.id = value
        socket.registerWires sprintWire
        
      @model.sessionid = sessionid
      socket.registerWires wires

_.extend StoryViewModel.prototype, parentMixin
_.extend StoryViewModel.prototype, sortableMixin
_.extend StoryViewModel.prototype, markdownMixin
