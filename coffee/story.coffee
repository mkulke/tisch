class StorySocketIO extends SocketIO

  ###_sort: (a, b) -> 

    a.priority > b.priority ? -1 : 1
  _onAdd: (data) =>

    if data.story_id == @view.get 'story._id'

      @model.children.objects.push(data)
  _onRemove: (data) =>

    if data.story_id == @view.get 'story._id'

      children = @model.children.objects
      child = _.findWhere children, {_id: data.id}
      if child? 

        index = _.indexOf children, child
        children.splice index, 1
      @view.set 'children', children
  _onUpdate: (data) =>

    update = (path) =>

      @view.set "#{path}._rev", data.rev
      @view.set "#{path}.#{data.key}", data.value

    if data.id == @view.get 'story._id' 

      update 'story'
      if data.key == 'sprint_id' 

        @model.getSprint data.value, (data) => 

          @view.set 'sprint', data
    else if data.id == @view.get 'sprint._id' then update 'sprint'
    
    # sprints from the selector
    sprintIndex = index for sprint, index in @view.get 'sprints' when sprint._id == data.id
    if sprintIndex? then update "sprints[#{sprintIndex}]"

    # tasks
    taskIndex = index for task, index in @view.get 'children' when task._id == data.id
    if taskIndex? 

      before = (child.priority for child in @view.get('children'))
      console.log "before: #{before}"

      update "children[#{taskIndex}]"
      if data.key == 'priority'

        children = @model.children.objects.slice()
        children.sort(@_sort)
        @model.children.objects = children
        @view.set 'children', children

      after = (child.priority for child in @view.get('children'))
      console.log "after: #{after}"

    # breadcrumbs
    if (@view.get 'breadcrumbs.sprint.id') == data.id && data.key == 'title' 

      @view.set 'breadcrumbs.sprint.title', data.value###

class StoryModel extends ParentModel

  type: 'story'
  constructor: (tasks, @story, @sprint) ->

  	@children = {type: 'task', objects: tasks}

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
  buildTimeSpentChartData: (timesSpent, range) ->

    initial = {}
    filteredTimesSpent = _.reduce timesSpent, (object, timeSpent) ->

      for key, value of timeSpent when range.start <= key <= range.end

        if object[key]? then object[key] += value
        else if value > 0 then object[key] = value
      object
    , initial

    if !_.isEmpty(filteredTimesSpent) && !filteredTimesSpent[range.start] then filteredTimesSpent[range.start] = 0

    data = ({date: key, value: value} for key, value of filteredTimesSpent).sort (a, b) -> 

      moment(a.date).unix() - moment(b.date).unix()

    # make it cumulative
    counter = 0
    _.map data, (object) ->

      {date: object.date, value: counter += object.value}
  buildRemainingTimeChartData: (estimation, remainingTimes, range) ->

    indices = _.map remainingTimes, (remainingTime) ->

      (index for index of remainingTime when range.start <= index <= range.end)
    indices = _.flatten indices
    indices = _.uniq indices

    data = _.reduce indices, (object, index) =>

      object[index] = _.reduce remainingTimes, (count, remainingTime) =>

        count += @getClosestValueByDateIndex remainingTime, index, range.start
      , 0
      object
    , {}        
    if !data[range.start] then data[range.start] = estimation

    ({date: key, value} for key, value of data).sort (a, b) -> moment(a.date).unix() - moment(b.date).unix()

class StoryViewModel extends ParentViewModel

  _updateStoryModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'story', property, value
  _updateTaskModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'task', property, value

  constructor: (@model) ->

    super(@model)

    # breadcrumbs

    @breadcrumbs =

      sprint:

        id: @model.sprint._id
        label: @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    # title

    @title = @_createThrottledObservable @model.story, 'title', @_updateStoryModel

    # description

    @description = @_createThrottledObservable @model.story, 'description', @_updateStoryModel

    # color

    @color = @_createObservable @model.story, 'color', @_updateStoryModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # sprint specific stuff

    @sprint = ko.observable @model.sprint
    @sprintTitle = ko.computed =>

      @sprint().title
    @sprintStart = ko.computed =>

      @sprint().start
    @sprintLength = ko.computed =>

      @sprint().length
    @sprintRange = ko.computed =>

      @model.buildSprintRange @sprintStart(), @sprintLength()

    # sprint_id

    @sprints = ko.observable()

    @sprintId = @_createObservable @model.story, 'sprint_id', @_updateStoryModel

    @showSprintSelector = => 

      @model.getSprints (sprints) =>

        @sprints sprints
        @modal 'sprint-selector'
    
    @selectSprint = (sprint) =>

      @modal null
      @sprintId sprint._id
      @sprint sprint

    # initial_estimation

    @estimation = @_createThrottledObservable(@model.story, 'estimation', @_updateStoryModel, true)
      .extend({matches: common.TIME_REGEX})

    # tasks

    createObservablesObject = (task) =>

      _id: task._id
      summary: @_createObservable task, 'summary', @_updateTaskModel
      description: @_createObservable task, 'description', @_updateTaskModel
      color: @_createObservable task, 'color', @_updateTaskModel
      priority: @_createObservable task, 'priority', @_updateTaskModel
      remaining_time: @_createObservable task, 'remaining_time', @_updateTaskModel
      time_spent: @_createObservable task, 'time_spent', @_updateTaskModel
      _url: '/task/' + task._id
      _js: task
      _remaining_time: ko.computed =>

        # TODO: verify the correct remaining_time object is used! (it should, tho)
        @model.buildRemainingTime task.remaining_time, @sprintRange()

    tasks = _.map @model.children.objects, createObservablesObject

    @tasks = ko.observableArray tasks
    @tasks.subscribe (changes) =>

      for change in changes

        if change.status == 'added'

          taskObservable = @tasks()[change.index]
          @model.children.objects.splice change.index, 0, taskObservable._js
        else if change.status == 'deleted'

          @model.children.objects.splice change.index, 1
    , null, 'arrayChange'

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

      @model.createTask @model.story._id

        , (task) => 
        
          observableObject = createObservablesObject task
          @tasks.push observableObject
          # TODO: sort after push?
        , showErrorDialog

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