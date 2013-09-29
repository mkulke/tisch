class StorySocketIO extends SocketIO

  messageHandler: (data) =>

    if data.message == 'update'
        
      #TODO: tasks
      if @view.get('story')._id == data.recipient

        @view.set "story._rev", data.data.rev
        @view.set "story.#{data.data.key}", data.data.value
        if data.data.key == 'sprint_id' 

          @model.getSprint data.data.value, (data) => 

            @view.set 'sprint', data
      else if @view.get('sprint')._id == data.recipient

        @view.set "sprint._rev", data.data.rev
        @view.set "sprint.#{data.data.key}", data.data.value
      else

        index = i for child, i in @view.get('children') when child._id == data.recipient

        if index?

          @view.set "children.#{index}._rev", data.data.rev
          @view.set "children.#{index}.#{data.data.key}", data.data.value
          if data.data.key == 'priority' then @view.get('children').sort (a, b) -> a.priority > b.priority ? -1 : 1

class StoryView extends View

  _buildRactiveData: =>

    breadcrumbs: 

      sprint: title: @model.sprint.title, id: @model.sprint._id
    children: @model.children.objects
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    sprints: [@model.sprint]
    error_message: "Dummy message"
    confirm_message: "Dummy message"
    buildRemainingTime: @buildRemainingTime
    buildTimeSpent: @buildTimeSpent
    buildSprintRange: @model.buildSprintRange
    countTasks: (tasks) -> 

      (key for key, value of tasks).length
    calculateRemainingTime: (tasks, range, buildFunction) ->

      tasks.reduce (count, task) -> 

        count + (buildFunction task.remaining_time, range)
      , 0
    buildAllTimeSpent: (tasks, range, buildFunction) ->

      tasks.reduce (count, task) -> 

        count + (buildFunction task.time_spent, range)
      ,0
    buildStatMatrix: @buildStatMatrix
  buildStatMatrix: (tasks, range) ->

    timeSpent = tasks.reduce (object, task) ->

      for key, value of task.time_spent when range.start <= key < range.end

        if object[key]? then object[key] += value
        else object[key] = value
      object
    , {}
    ({date: key, time_spent: value} for key, value of timeSpent)
  buildTimeSpent: (timeSpent, range) ->

    spentTimes = (value for key, value of timeSpent when range.start <= key < range.end)
    spentTimes.reduce (count, spentTime) ->

      count + spentTime
    ,0
  buildRemainingTime: (remainingTime, range) ->

    dates = (key for key of remainingTime when range.start <= key < range.end).sort()

    if dates.length == 0

      remainingTime.initial
    else

      latest = dates[dates.length - 1]
      remainingTime[latest]

class StoryModel extends Model

  type: 'story'
  constructor: (tasks, @story, @sprint) ->

  	@children = {type: 'task', objects: tasks}

  buildSprintRange: (sprint) ->

    start = moment sprint.start
    end = moment(start).add 'days', sprint.length
    start: start.format('YYYY-MM-DD'), end: end.format('YYYY-MM-DD')
  buildChartData: (tasks, range) ->

    timeSpent = tasks.reduce (object, task) ->

      for key, value of task.time_spent when range.start <= key < range.end

        if object[key]? then object[key] += value
        else object[key] = value
      object
    , {}

    sortedData = ({x: moment(key).valueOf(), y: value} for key, value of timeSpent).sort (a,b) -> a.x > b.x ? -1 : 1
    # make it cumulative
    ySeed = 0
    for coord in sortedData

      coord.y = coord.y + ySeed
      ySeed = coord.y
    sortedData

class StoryViewModel extends ChildViewModel

  constructor: (@model, ractiveTemplate) ->

    @view = new StoryView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation, [id^="summary-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element
    $('#estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' 

        undoValue = @view.get 'story.color'
        @view.set 'story.color', args.value
        @model.update 'color'

          ,(data) => @view.set 'story._rev', data.rev
          ,(message) => 
          
            @view.set 'story.color', undoValue
            #TODO: error output
      when 'sprint-selector' 

        undoValue = @view.get 'story.sprint_id'
        @view.set 'story.sprint_id', args.value
        @model.update 'sprint_id'

          ,(data) => 

            @view.set 'story._rev', data.rev
            @model.getSprint data.value, (data) => 

              @view.set 'sprint', data
          ,(message) =>

            @view.set 'story.sprint_id', undoValue
            #TODO: error output
  openSelectorPopup: (ractiveEvent, id) =>

	  switch id
	    
	    when 'sprint-selector' then @model.getSprints (data) =>

	      @view.set 'sprints', data
	      @_showPopup(id)
	    else @_showPopup(id)
  updateChart: =>

    series = [
        
      color: 'steelblue'
      data: @model.buildChartData @model.children.objects, @model.buildSprintRange @model.sprint
    ]

    if @graph?

      @graph.configure

        series: series
    else

      @graph = new Rickshaw.Graph

        element: $('#chart').get(0)
        width: $('#stats-dialog .content').width() - $('#stats-dialog .textbox').width()
        height: 200
        series: series
      @graph.render()

      xAxis = new Rickshaw.Graph.Axis.Time

        graph: @graph
        timeFixture: new Rickshaw.Fixtures.Time.Local()
      xAxis.render()
  hideStats: =>

    @_hideModal 'stats'
  showStats: => 

    @updateChart()
    @_showModal 'stats'
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      # TODO: confirm
      when 'story_remove'

        @showError 'Not implemented yet!'
        #@model.removeStory @model.story, (=>), (message) => @showError message
      when 'task_add' 

        @model.createTask @model.get('_id')
          ,(data) => 

            @model.children.objects.push data
            $("#summary-#{data._id}, #description-#{data._id}").each (index, element) => @_setConfirmedValue element
          ,(message) => 

            @showError message
      when 'task_open' then window.location.href = "/task/#{ractiveEvent.context._id}"
      when 'task_remove' 

        @onConfirm = => 

          @model.removeTask ractiveEvent.context
            , (id) => 

              @view.get('children').splice ractiveEvent.index.i, 1
            ,(message) => 

              @showError message
        @showConfirm common.constants.en_US.CONFIRM_TASK_REMOVAL ractiveEvent.context.summary
      when 'confirm_confirm' then @onConfirm()
      when 'show_stats' 

        @showStats()
      when 'stats_close' 

        @hideStats()