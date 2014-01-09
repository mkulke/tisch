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

    writables = _.reduce [

      {name: 'summary', throttled: true}
      {name: 'description', throttled: true}
      {name: 'priority'}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}
    
    _id: task._id
    summary: writables.summary
    description: writables.description
    color: ko.observable task.color
    priority: writables.priority
    remaining_time: ko.observable task.remaining_time
    time_spent: ko.observable task.time_spent
    _url: '/task/' + task._id
    _js: task
    _remaining_time: ko.computed =>

      # TODO: verify the correct remaining_time object is used! (it should, tho)
      @model.buildRemainingTime task.remaining_time, @sprintRange()

  _createStoryNotifications: ->

    update =

      properties: _.chain(@model.story).keys().reject((a) -> a[0] == '_').value()
      handler: (data) =>

        @model.story._rev = data.rev
        @model.story[data.key] = data.value
        @[data.key]?(data.value)
        if data.key == 'sprint_id'

          @model.getSprint @sprint_id(), @_replaceSprint
    add = 

      method: 'PUT'
      handler: partial @_addChild, @tasks

    [update, add]

  _createTaskNotifications: (observablesObject) =>

    update = 

      id: observablesObject._id
      properties: ['summary', 'description', 'color', 'priority']
      handler: (data) =>

        debugger;
        task = observablesObject._js
        task._rev = data.rev
        task[data.key] = data.value
        observablesObject[data.key] data.value

    remove = 

      method: 'DELETE'
      id: observablesObject._id
      handler: =>

        @tasks.remove (item) ->

          item._id == observablesObject._id

    [update, remove]

  _createSprintNotification: ->

    id: @sprint_id()
    properties: ['title', 'start', 'length']
    handler: (data) =>

      @sprint[data.key] data.value

  _createBreadcrumbNotification: ->

    id: @breadcrumbs.sprint.id
    properties: ['title']
    handler: (data) ->

      @breadcrumbs.sprint.label data.value

  _replaceSprint: (sprint) =>

    for key, value of _.chain(sprint).pick('title', 'start', 'length').value()

      @sprint[key] value

  constructor: (@model) ->

    super(@model)

    # TODO: use mixins
    # set global options for jquery ui sortable

    ko.bindingHandlers.sortable.options = 

      tolerance: 'pointer'
      delay: 150
      cursor: 'move'
      containment: 'ul#well'
      handle: '.header'

    # breadcrumbs

    @breadcrumbs =

      sprint: 

        id: @model.sprint._id
        label: ko.observable @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    # test

    updateModel = partial(@_updateModel, 'story');
    updateChildModel = partial(@_updateModel, 'task');

    # title

    @title = @_createThrottledObservable @model.story, 'title', updateModel

    # description

    @description = @_createThrottledObservable @model.story, 'description', updateModel

    # color

    @color = @_createObservable @model.story, 'color', updateModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # sprint_id

    @sprints = ko.observable()

    @sprint_id = @_createObservable @model.story, 'sprint_id', updateModel

    @showSprintSelector = => 

      @model.getSprints (sprints) =>

        @sprints _.map sprints, (sprint) ->

          {id: sprint._id, label: sprint.title}
        @modal 'sprint-selector'
    
    @selectSprint = (selected) =>

      @modal null
      @model.getSprint selected.id

        , (sprint) =>

          @sprint_id sprint._id
          @_replaceSprint sprint
        , @_showError

    # sprint specific stuff

    @sprint = 

      _id: ko.computed =>

        @sprint_id()
      title: ko.observable @model.sprint.title
      start: ko.observable @model.sprint.start
      length: ko.observable @model.sprint.length
    @sprintRange = ko.computed =>

      @model.buildSprintRange @sprint.start(), @sprint.length()

    # initial_estimation

    @estimation = @_createThrottledObservable(@model.story, 'estimation', updateModel, true)
      .extend({matches: common.TIME_REGEX})

    # tasks

    @tasks = ko.observableArray _.map @model.tasks, @_createObservables
    _.chain(@tasks()).pluck('priority').invoke('subscribe', partial(@_sortByPriority, @tasks))

    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @model.calculatePriority @tasks(), arg.sourceIndex, arg.targetIndex
      arg.item.priority priority

    # confirmation dialog specific

    @confirmMessage = ko.observable()
    @cancel = =>

      @modal null

    # button handlers

    showErrorDialog = (message) =>

      @modal 'error-dialog'
      @errorMessage message

    @addTask = =>

      @model.createTask @model.story._id, partial(@_addChild, @tasks), showErrorDialog

    @removeTask = (taskObservable) =>

      @modal 'confirm-dialog'
      # TODO: i18n
      @confirmMessage 'Are you sure? The task will be permanently removed.'
      @confirm = =>

        @modal null
        task = taskObservable._js
        @model.removeTask task

          , =>

            @tasks.remove (item) =>

              item._id == task._id
          , showErrorDialog

    # stats

    @allRemainingTime = ko.computed =>

      _.reduce @tasks(), (count, task) =>

        count + @model.buildRemainingTime task.remaining_time(), @sprintRange()
      , 0      

    @allTimeSpent = ko.computed =>

      _.reduce @tasks(), (count, task) => 

        count + @model.buildTimeSpent task.time_spent(), @sprintRange()
      ,0

    @remainingTimeChartData = ko.computed =>

      remainingTimes = _.map @tasks(), (task) ->

        task.remaining_time()
      @model.buildRemainingTimeChartData @estimation(), remainingTimes, @sprintRange()

    @timeSpentChartData = ko.computed =>

      timesSpent = _.map @tasks(), (task) ->

        task.time_spent()
      @model.buildTimeSpentChartData timesSpent, @sprintRange()

    chart = new Chart ['reference', 'remaining-time', 'time-spent']
    refreshChart = =>

      # TODO: chart render issues when sprint range is modified.
      chart.refresh 

        'remaining-time': @remainingTimeChartData()
        'time-spent': @timeSpentChartData()
        reference: [

          {date: @sprintRange().start, value: @estimation()}
          {date: moment(@sprintRange().end).format(common.DATE_DB_FORMAT), value: 0}
        ]
    refreshChart()
    @remainingTimeChartData.subscribe (value) =>

      refreshChart()
    @timeSpentChartData.subscribe (value) =>

      refreshChart()      

    @showStats = =>

      @modal 'stats-dialog'

    @closeStats = =>

      @modal null

   # realtime specific initializations

    notifications = []
    defaults = 

      method: 'POST'
      id: @model.story._id

    notifications = notifications.concat @_createStoryNotifications()

    notifications.push sprintNotification = @_createSprintNotification()

    @sprint_id.subscribe (value) ->

      if value != sprintNotification

        socket.unregisterNotifications sprintNotification
        sprintNotification.id = value
        socket.registerNotifications sprintNotification

    notifications.push @_createBreadcrumbNotification()

    notifications = notifications.concat _.chain(@tasks()).map(@_createTaskNotifications).flatten().value()

    _.each notifications, curry2(_.defaults)(defaults)

    @tasks.subscribe (changes) =>

      for change in changes

        if change.status == 'added'

          taskObservable = @tasks()[change.index]
          taskNotifications = @_createTaskNotifications taskObservable, change.index
          _.each notifications, curry2(_.defaults)(defaults)
          socket.registerNotifications taskNotifications
          notifications = notifications.concat taskNotifications
        else if change.status == 'deleted'

          socket.unregisterNotifications _.where(notifications, {id: change.value._id})
    , null, 'arrayChange'

    socket = new SocketIO()
    socket.connect (sessionid) =>

      @model.sessionid = sessionid
      socket.registerNotifications notifications 