class StoryModel extends ParentModel

  type: 'story'
  constructor: (@tasks, @story, @sprint) ->

  buildTimeSpent: (timeSpent, range) ->

    spentTimes = (value for key, value of timeSpent when range.start <= key <= range.end)
    spentTimes.reduce (count, spentTime) ->

      count + spentTime
    ,0

  buildRemainingTime: (remainingTime, range) ->

    dates = (key for key of remainingTime when range.start <= key <= range.end).sort()

    if dates.length == 0

      remainingTime.initial
    else

      latest = dates[dates.length - 1]
      remainingTime[latest] 

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

    getAndAdd = (index, count, remainingTime) =>

      count += @getClosestValueByDateIndex remainingTime, index, range.start

    toD3 = (index) ->

      {date: index, value: _.reduce remainingTimes, partial(getAndAdd, index), 0}

    prepend = (data) ->

      if _.first(data)?.date != range.start

        data.unshift {date: range.start, value: estimation}

    _.chain(remainingTimes).reduce(partial(@_collectIndices, range), []).map(toD3).tap(prepend).value()

class StoryViewModel extends ParentViewModel

  _createObservables: (task) =>

    updateModel = partial @_updateModel, 'task'
    createObservable_ = partial @_createObservable3, updateModel, task

    id: task._id
    url: '/task/' + task._id
    js: task
    computed:

      remaining_time: ko.computed =>

        @model.buildRemainingTime task.remaining_time, @sprint.computed.range()
    readonly:

      color: ko.observable task.color
      remaining_time: ko.observable task.remaining_time
      time_spent: ko.observable task.time_spent    
    writable: _.reduce [

      {name: 'summary', throttled: true}
      {name: 'description', throttled: true}
      {name: 'priority'}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}

  _replaceSprint: (sprint) =>

    for key, value of _.chain(sprint).pick('title', 'start', 'length').value()

      @sprint.readonly[key] value

  showColorSelector: =>

    @modal 'color-selector'
  
  selectColor: (color) =>

    @modal null
    @writable.color color

  sprints: ko.observable()

  showSprintSelector: => 

    @model.getSprints (sprints) =>

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

    @model.createTask @model.story._id, partial(@_addChild_, @tasks), @showErrorDialog

  removeTask: (observables) =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The task will be permanently removed.', =>

      task = observables.js
      @model.removeTask task, =>

        @tasks.remove (item) =>

          item.id == task._id
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

    # breadcrumbs

    @breadcrumbs =

      sprint: 

        id: @model.sprint._id
        readonly:

          title: ko.observable @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    # observables

    updateModel = partial(@_updateModel, 'story');
    createObservable_ = partial @_createObservable3, updateModel, @model.story

    @writable = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'color'}
      {name: 'sprint_id'}
      {name: 'estimation', throttled: true, time: true}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}

    # sprint specific stuff

    @sprint = do =>

      start = ko.observable @model.sprint.start
      length = ko.observable @model.sprint.length

      computed:

        id: ko.computed =>

          @writable.sprint_id
        range: ko.computed =>

          @model.buildSprintRange start(), length()
      readonly:

        title: ko.observable @model.sprint.title
        start: start
        length: length

    # tasks

    @tasks = ko.observableArray _.map @model.tasks, @_createObservables
    _.chain(@tasks()).pluck('writable').pluck('priority').invoke('subscribe', partial(@_sortByPriority_, @tasks))

    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @model.calculatePriority_ @tasks(), arg.targetIndex
      arg.item.writable.priority priority

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

    # realtime specific initializations

    notifications = []
    observables = _.extend {}, @writable, @readonly
    notifications.push @_createUpdateNotification(@model.story, observables)
    notifications.push @_createAddNotification(@model.story._id, @tasks)

    notifications.push sprintNotification = @_createUpdateNotification(@model.sprint, @sprint.readonly)
    @writable.sprint_id.subscribe (value) =>

      @model.getSprint value, @_replaceSprint
      socket.unregisterNotifications sprintNotification
      sprintNotification.id = value
      socket.registerNotifications sprintNotification

    notifications.push @_createUpdateNotification(_.pick(@model.sprint, '_id'), @breadcrumbs.sprint.readonly)

    notifications = notifications.concat _.chain(@tasks()).map(partial(@_createChildNotifications, @tasks)).flatten().value()
    
    socket = new SocketIO()
    socket.connect (sessionid) =>

      @tasks.subscribe partial(@_adjustNotifications, socket, @tasks, notifications), null, 'arrayChange'
      @model.sessionid = sessionid
      socket.registerNotifications notifications
