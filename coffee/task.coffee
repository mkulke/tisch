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

  _replaceStory: (story) =>

    _.chain(story).pick('title', 'sprint_id').each (value, key) =>

      @story.readonly[key] value

  _replaceSprint: (sprint) =>

    _.chain(sprint).pick('title', 'start', 'length').each (value, key) =>

      @sprint.readonly[key] value

  _createIndexedComputed: (read, write, owner) ->

    # Create a throttled observable and a writable computed. In the write fn there is a immediate
    # regex validation, the hasError observable property is set accordingly. Then the throttled
    # observable is updated, which triggers a subscribe fn to be called. In that fn the actual
    # write fn is called when the hasError observable property is false. 

    throttled = ko.observable().extend({throttle: common.KEYUP_UPDATE_DELAY})   
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

  # TODO: as mixin plz
  showColorSelector: =>

    @modal 'color-selector'
  selectColor: (color) =>

    @modal null
    @writable.color color

  showStorySelector: => 

    @model.getStories @model.story.sprint_id, (stories) =>

      @stories _.map stories, (story) ->

        {id: story._id, label: story.title}
      @modal 'story-selector'
  
  selectStory: (selected) =>

    @modal null
    @writable.story_id selected.id
    # story specific stuff

  showRemainingTimeDatePicker: => 

    @modal 'remaining_time-index'

  remove: =>

    # TODO: i18n
    @_afterConfirm 'Are you sure? The task will be permanently removed.', =>

      @model.removeTask @model.task, => 

        window.location.replace '/story/' + @story.computed.id()
      , @showErrorDialog

  constructor: (@model) ->

    super(@model)   

    # breadcrumbs

    @breadcrumbs =

      story: 

        id: @model.story._id
        readonly:

          title: ko.observable @model.story.title
        url: '/story/' + @model.story._id
      sprint:

        id: @model.sprint._id
        readonly:

          title: ko.observable @model.sprint.title
        url: '/sprint/' + @model.sprint._id

    updateModel = partial @_updateModel, 'task'
    createObservable = partial @_createObservable, updateModel, @model.task

    @writable = _.reduce [

      {name: 'summary', throttled: true}
      {name: 'description', throttled: true}
      {name: 'color'}
      {name: 'story_id'}
      {name: 'initial_estimation', throttled: true, time: true}
      {name: 'remaining_time'}
      {name: 'time_spent'}
    ], (object, property) ->

      object[property.name] = createObservable property.name, _.omit(property, 'name'); object
    , {}

    # story_id

    @stories = ko.observable()

    @writable.story_id.subscribe (value) =>

      @model.getStory value, @_replaceStory, @_showError

    @story = 

      computed: 

        id: ko.computed => 

          @writable.story_id()
      readonly:
      
        title: ko.observable @model.story.title
        sprint_id: ko.observable @model.story.sprint_id

    # sprint specific observables

    @sprint = do =>

      start = ko.observable @model.sprint.start
      length = ko.observable @model.sprint.length

      computed:

        id: ko.computed =>

          @story.readonly.sprint_id()
        range: ko.computed =>

          @model.buildSprintRange start(), length()
      readonly:

        title: ko.observable @model.sprint.title
        start: start
        length: length

    # In case the sprint changes we might have to reset indexes, so they do not point at out-of-sprint dates.
    @sprint.computed.range.subscribe (range) =>

      _.each [@timeSpentIndex, @remainingTimeIndex], (indexObservable) =>

        index = indexObservable()
        if index < range.start || index > range.end

          newIndex = @model.getDateIndex @sprint.start(), @sprint.length()
          indexObservable newIndex

    # shared write for indexed properties (remaining_time & time_spent)
    writeIndexed = (property, observableObject, observableIndex, value) =>

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

    initialDateIndex = @model.getDateIndex @sprint.readonly.start(), @sprint.readonly.length()

    # remaining_time   

    @remainingTimeIndex = ko.observable initialDateIndex
    @remainingTimeIndexFormatted = ko.computed =>

      formatDateIndex @remainingTimeIndex()

    readRemainingTime = =>

      @model.getClosestValueByDateIndex @writable.remaining_time(), @remainingTimeIndex(), @sprint.computed.range().start
    @indexedRemainingTime = @_createIndexedComputed readRemainingTime, partial(writeIndexed, 'remaining_time', @writable.remaining_time, @remainingTimeIndex), @

    # time_spent

    @timeSpentIndex = ko.observable initialDateIndex
    @timeSpentIndexFormatted = ko.computed =>    

      formatDateIndex @timeSpentIndex()

    @showTimeSpentDatePicker = => @modal 'time_spent-index'

    readTimeSpent = =>

      value = @writable.time_spent()[@timeSpentIndex()]
      if value? then value else 0
    @indexedTimeSpent = @_createIndexedComputed readTimeSpent, partial(writeIndexed, 'time_spent', @writable.time_spent, @timeSpentIndex), @

    # rt specific initializations

    wires = []
    observables = _.extend {}, @writable, @readonly
    wires.push @_createUpdateWire(@model.task, observables)
    wires.push sprintWire = @_createUpdateWire(@model.sprint, @sprint.readonly)
    wires.push storyWire = @_createUpdateWire(@model.story, @story.readonly)
    wires.push @_createUpdateWire(_.pick(@model.story, '_id'), @breadcrumbs.story.readonly)
    wires.push @_createUpdateWire(_.pick(@model.sprint, '_id'), @breadcrumbs.sprint.readonly)
    
    socket = new SocketIO()
    socket.connect (sessionid) =>

      replace = (wire, getFn, replaceFn, value) =>

        @model[getFn].call(null, value, replaceFn)
        socket.unregisterWires wire
        wire.id = value
        socket.registerWires wire

      @story.readonly.sprint_id.subscribe partial(replace, sprintWire, 'getSprint', @_replaceSprint)
      @writable.story_id.subscribe partial(replace, storyWire, 'getStory', @_replaceStory)

      @model.sessionid = sessionid
      socket.registerWires wires