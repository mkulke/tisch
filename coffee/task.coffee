class TaskSocketIO extends SocketIO
  
  _onupdate: (data) =>

    if data.id == @model.task._id

      @model.task._rev = data.rev
      @model.task[data.key] = data.value
      switch data.key

        when 'story_id'

          # if story is not there fetch new story
          story = _.find @viewModel.stories(), (story) ->

            story._id == data.value
          if !story?

            @model.getStory data.value, (data) =>

              @viewModel.stories([data])
              @viewModel.storyId(data.value)
          else 

            @viewModel.storyId(data.value)

        when 'remaining_time'

          @viewModel.remainingTime(data.value)
        when 'time_spent'

          @viewModel.timeSpent(data.value)
        else

          @viewModel[data.key]?(data.value)
  # TODO: when sprint_id changes for story_id get new sprint!
  # TODO: when title changes for story_id 
class TaskModel extends Model

  type: 'task'
  constructor: (@task, @story, @sprint) ->
  getDateIndex: (sprintStart, sprintLength) ->

    current = new moment()
    start = new moment sprintStart
    inclusiveEnd = start.clone().add('days', sprintLength - 1)
    dateIndex = 

      if current < start then start
      else if current > inclusiveEnd then inclusiveEnd 
      else current
    dateIndex.format(common.DATE_DB_FORMAT)
  getClosestValueByDateIndex: (object, index, startIndex) ->

    if object[index]?

      object[index]
    else

      sortedKeys = Object.keys(object).sort()
      filteredKeys = sortedKeys.filter (key) -> 

        index > key >= startIndex
      if filteredKeys.length > 0 

        object[filteredKeys.pop()]
      else

        object.initial
  set: (key, value, index) =>

    if index? then @[@type][key][index] = value
    else @[@type][key] = value

class TaskViewModel extends ViewModel

  _createIndexedComputed: (read, write, owner) ->

    # Create a throttled observable and a writable computed. In the write fn there is a immediate
    # regex validation, the hasError observable property is set accordingly. Then the throttled
    # observable is updated, which triggers a subscribe fn to be called. In that fn the actual
    # write fn is called when the hasError observable property is false. 

    throttled = ko.observable().extend({throttle: common.KEYuP_uPDATE_DELAY})   
    indexed = ko.computed

      read: read
      write: (value) ->

        indexed.hasError(value.toString().search(common.TIME_REGEX) != 0)
        throttled(value)
      owner: owner
    indexed.hasError = ko.observable()
    throttled.subscribe (value) ->

      if !indexed.hasError()

        write value   
    indexed

  _updateTaskModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'task', property, value

  constructor: (@model) ->

    super(@model)   

    @breadcrumbs =

      story:

        id: @model.story._id
        label: @model.story.title
        url: '/story/' + @model.story._id
      sprint:

        id: @model.sprint._id
        label: @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    #summary

    @summary = @_createThrottledObservable @model.task, 'summary', @_updateTaskModel
    
    #description

    @description = @_createThrottledObservable @model.task, 'description', @_updateTaskModel
    
    #color

    @color = @_createObservable @model.task, 'color', @_updateTaskModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # story_id

    @stories = ko.observable [@model.story]

    @storyId = @_createObservable @model.task, 'story_id', @_updateTaskModel
    @storyIdFormatted = ko.computed =>

      story = _.find @stories(), (story) =>

        story._id == @storyId()
      story?.title

    @showStorySelector = => 

      @model.getStories @model.story.sprint_id, (data) =>

        @stories data
        @modal 'story-selector'
    
    @selectStory = (story) =>

      @modal null
      @storyId story._id

    # initial_estimation

    @initialEstimation = @_createThrottledObservable(@model.task, 'initial_estimation', @_updateTaskModel, true)
      .extend({matches: common.TIME_REGEX})

    # sprint specific observables

    @sprint = ko.observable @model.sprint
    @sprintStart = ko.computed =>

      @sprint().start
    @sprintLength = ko.computed =>

      @sprint().length
    @sprintRange = ko.computed =>

      @model.buildSprintRange @sprintStart(), @sprintLength()

    initialDateIndex = @model.getDateIndex @sprintStart(), @sprintLength()

    # story specific observables (note: this is for breadcrumbs, so it should not change with story rassignments)

    @story = ko.observable @model.story
    @storyUrl = ko.computed =>

      '/story/' + @story()._id

    # shared write curry for indexed properties (remaining_time & time_spent)

    writeIndexed = curry (property, observableObject, observableIndex, value) =>

      # we need to clone the obj, b/c otherwise the observable would not be updated
      oldObject = observableObject()
      object = _.clone oldObject
      object[observableIndex()] = parseFloat value, 10
      if !_.isEqual(oldObject, object)
      
        observableObject(object)   
        @model.task[property] = object
        @model.update @model.task, property, 'task', null, (message) =>

          @model.task[property] = oldObject
          observableObject(oldObject)
          @modal 'error-dialog'
          @errorMessage message

    formatDateIndex = (dateIndex) -> 

      moment(dateIndex).format(common.DATE_DISPLAY_FORMAT)

    # remaining_time   

    @showRemainingTimeDatePicker = => 

      @modal 'remaining_time-index'

    @remainingTimeIndex = ko.observable initialDateIndex
    @remainingTimeIndexFormatted = ko.computed =>

      formatDateIndex @remainingTimeIndex()

    @remainingTime = ko.observable @model.task.remaining_time

    readRemainingTime = =>

      @model.getClosestValueByDateIndex @remainingTime(), @remainingTimeIndex(), @sprintRange().start
    @indexedRemainingTime = @_createIndexedComputed readRemainingTime, writeIndexed('remaining_time', @remainingTime, @remainingTimeIndex), @

    # time_spent

    @timeSpentIndex = ko.observable initialDateIndex
    @timeSpentIndexFormatted = ko.computed =>    

      formatDateIndex @timeSpentIndex()

    @showTimeSpentDatePicker = => @modal 'time_spent-index'

    @timeSpent = ko.observable @model.task.time_spent
    @timeSpent.subscribe (value) ->

      console.log "time_spent: #{JSON.stringify(value)}"

    readTimeSpent = =>

      value = @timeSpent()[@timeSpentIndex()]
      if value? then value else 0
    @indexedTimeSpent = @_createIndexedComputed readTimeSpent, writeIndexed('time_spent', @timeSpent, @timeSpentIndex), @