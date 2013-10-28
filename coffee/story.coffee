class StorySocketIO extends SocketIO

  _sort: (a, b) -> 

    a.priority > b.priority ? -1 : 1
  _onAdd: (data) =>

    if data.story_id == @view.get 'story._id'

      @model.children.objects.push(data)
  _onRemove: (data) =>

    if data.story_id == @view.get 'story._id'

      children = @view.get 'children'
      child = _.findWhere children, {_id: data.id}
      if child? 

        index = _.indexOf children, child
        children.splice index, 1
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

        @view.get('children').sort(@_sort)
        @view.update('children')

      after = (child.priority for child in @view.get('children'))
      console.log "after: #{after}"

    # breadcrumbs
    if (@view.get 'breadcrumbs.sprint.id') == data.id && data.key == 'title' 

      @view.set 'breadcrumbs.sprint.title', data.value

  ###messageHandler: (data) =>

    #if data.message == 'update'
        
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
          if data.data.key == 'priority' then @view.get('children').sort (a, b) -> a.priority > b.priority ? -1 : 1###

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
    sortChildren: (children) ->

      children = children.slice()
      children.sort (a, b) ->

        a.priority > b.priority ? -1 : 1
    countTasks: (tasks) -> 

      (key for key, value of tasks).length
    calculateRemainingTime: (tasks, range, buildFunction) ->

      _.reduce tasks, (count, task) -> 

        count + (buildFunction task.remaining_time, range)
      , 0
    buildAllTimeSpent: (tasks, range, buildFunction) ->

      _.reduce tasks, (count, task) -> 

        count + (buildFunction task.time_spent, range)
      ,0
    ###buildTSMatrix: (tasks, range) ->

      timeSpent = tasks.reduce (object, task) ->

        for key, value of task.time_spent when range.start <= key < range.end

          if object[key]? then object[key] += value
          else if value != 0 then object[key] = value
        object
      , {}
      ({date: key, time_spent: value} for key, value of timeSpent)
    buildRTMatrix: (tasks, range) ->

      testo = (remainingTime, index) ->

        if remainingTime[index]? then remainingTime[index]
        else

          # in this case check for the next date w/ a value *before*, but *within* the sprint
          value = remainingTime.initial

          indexDate = moment(index)
          while indexDate.subtract('days', 1) >= range.start

            if remainingTime[indexDate.format(common.DATE_DB_FORMAT)]?

              value = remainingTime[indexDate.format(common.DATE_DB_FORMAT)]
              break
          value

      indices = tasks.reduce (object, task) ->

        object[index] = true for index of task.remaining_time when range.start <= index < range.end
        object
      , {}

      remainingTime = {}
      for index of indices

        remainingTime[index] = tasks.reduce (count, task) ->

          count += testo task.remaining_time, index
        , 0
      ({date: key, remaining_time: value} for key, value of remainingTime)###
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
    start: start.format(common.DATE_DB_FORMAT), end: end.format(common.DATE_DB_FORMAT)
  buildTimeSpentChartData: (tasks, range) ->

    initial = {}
    timeSpent = _.reduce tasks, (object, task) ->

      #x = ({date: key, value} for key, value of task.time_spent)
      #y = _filter x (z) -> range.start <= z.date < range.end
      for key, value of task.time_spent when range.start <= key < range.end

        if object[key]? then object[key] += value
        else if value > 0 then object[key] = value
      object
    , initial

    if !_.isEmpty(timeSpent) && !timeSpent[range.start] then timeSpent[range.start] = 0

    data = ({date: key, value: value} for key, value of timeSpent).sort (a, b) -> moment(a.date).unix() - moment(b.date).unix()

    # make it cumulative
    counter = 0
    _.map data, (object) ->

      {date: object.date, value: counter += object.value}
  buildRemainingTimeChartData: (story, tasks, range) ->

    indices = _.map tasks, (task) ->

      (index for index of task.remaining_time when range.start <= index < range.end)
    indices = _.flatten indices
    indices = _.uniq indices

    remainingTimes = _.reduce indices, (object, index) =>

      object[index] = _.reduce tasks, (count, task) =>

        count += @_getClosestValueByDateIndex task.remaining_time, index, range.start
      , 0
      object
    , {}        
    if !remainingTimes[range.start] then remainingTimes[range.start] = story.estimation

    ({date: key, value} for key, value of remainingTimes).sort (a, b) -> moment(a.date).unix() - moment(b.date).unix()

class StoryViewModel extends ChildViewModel

  constructor: (@model, ractiveTemplate) ->

    @view = new StoryView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new StorySocketIO @view, @model

    $('#title, #description, #estimation, [id^="summary-"], [id^="description-"]').each (index, element) => @_setConfirmedValue element
    $('#estimation').data 'validation', (value) -> value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
    @chart = new Chart ['reference', 'remainingTime', 'timeSpent']
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
  hideStats: =>

    @_hideModal 'stats'
  showStats: => 

    range = @model.buildSprintRange @model.sprint
    remainingTime = @model.buildRemainingTimeChartData @model.story, @model.children.objects, range
    timeSpent = @model.buildTimeSpentChartData @model.children.objects, range

    @chart.refresh 

      remainingTime: remainingTime
      timeSpent: timeSpent
      reference: [

        {date: range.start, value: @model.story.estimation}
        {date: moment(range.end).subtract('days', 1).format(common.DATE_DB_FORMAT), value: 0}
      ]
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