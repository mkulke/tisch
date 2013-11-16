class TaskSocketIO extends SocketIO
  
  _onUpdate: (data) =>

    update = (path) =>

      @view.set "#{path}._rev", data.rev
      @view.set "#{path}.#{data.key}", data.value

    if data.id == @view.get 'task._id' 

      update 'task'
      if data.key == 'story_id' then @model.getStory data.value, (data) => 

        @view.set 'story', data
    else if data.id == @view.get 'story._id' 

      update 'story'
      if data.key == 'sprint_id' 

        @model.getSprint data.value, (data) => 

          @view.set 'sprint', data
        #also get new stories for the selector
        @model.getStories data.value, (data) =>

          @view.set 'stories', data

    else if data.id == @view.get 'sprint._id' then update 'sprint'
    
    # stories from the selector
    storyIndex = index for story, index in @view.get 'stories' when story._id == data.id
    if storyIndex? then update "stories[#{storyIndex}]"

    # breadcrumbs
    if (@view.get 'breadcrumbs.story.id') == data.id && data.key == 'title'

      @view.set 'breadcrumbs.story.title', data.value
    else if (@view.get 'breadcrumbs.sprint.id') == data.id && data.key == 'title' 

      @view.set 'breadcrumbs.sprint.title', data.value

class TaskView extends View
 
  ###_buildRactiveData: =>

    breadcrumbs: 

      story: title: @model.story.title, id: @model.story._id
      sprint: title: @model.sprint.title, id: @model.sprint._id
    task: @model.task
    story: @model.story
    COLORS: common.COLORS
    constants: common.constants
    sprint: @model.sprint
    stories: [@model.story]
    getDateIndex: @model.getDateIndex
    time_spent_index: @model.getDateIndex(@model.sprint)
    remaining_time_index: @model.getDateIndex(@model.sprint)
    formatTimeSpent: (timeSpent, index) ->

      if timeSpent[index]? then timeSpent[index]
      else 0
    formatRemainingTime: (remainingTime, index, sprint) => 

      startIndex = moment(sprint.start).format(common.DATE_DB_FORMAT)      
      @model._getClosestValueByDateIndex remainingTime, index, startIndex
    formatDateIndex: (dateIndex) -> 

      moment(dateIndex).format(common.DATE_DISPLAY_FORMAT)
    error_message: "Dummy message"###
class TaskModel extends Model

  type: 'task'
  constructor: (@task, @story, @sprint) ->
  getDateIndex: (sprint) ->

    currentDate = new moment()
    sprintStart = new moment sprint.start
    sprintInclusiveEnd = sprintStart.clone().add('days', sprint.length - 1)
    dateIndex = 

      if currentDate < sprintStart then sprintStart
      else if currentDate > sprintInclusiveEnd then sprintInclusiveEnd 
      else currentDate
    dateIndex.format(common.DATE_DB_FORMAT)
  set: (key, value, index) =>

    if index? then @[@type][key][index] = value
    else @[@type][key] = value

class TaskViewModel extends ViewModel

  _createObservable: (object, property) ->

    observable = ko.observable object[property]
    observable.subscribe (value) ->

      if !observable.hasError
      
        alert "#{property} set to #{value}"    
    observable

  _createThrottledObservable: (object, property, numeric) ->

    instantaneousProperty = ko.observable(object[property])
    observable = ko.computed(instantaneousProperty).extend({throttle: common.KEYUP_UPDATE_DELAY})
    observable.subscribe (value) ->

      if !instantaneousProperty.hasError()

        object[property] = if numeric? then parseFloat value, 10 else value
        alert "#{property} set to #{value}"
    instantaneousProperty

  _createIndexedComputed: (read, write, owner, regex) =>

    # Create a throttled observable and a writable computed. In the write fn there is a immediate
    # regex validation, the hasError observable property is set accordingly. Then the throttled
    # observable is updated, which triggers a subscribe fn to be called. In that fn the actual
    # write fn is called when the hasError observable property is false. 

    throttled = ko.observable().extend({throttle: common.KEYUP_UPDATE_DELAY})   
    indexed = ko.computed

      read: read
      write: (value) ->

        indexed.hasError(value.toString().search(regex) != 0)
        throttled(value)
      owner: owner
    indexed.hasError = ko.observable()
    throttled.subscribe (value) ->

      if !indexed.hasError()

        write value   
    indexed

  constructor: (@model) ->

    ko.extenders.matches = (target, regex) ->

      target.hasError = ko.observable()
      target.validationMessage = ko.observable()

      validate = (newValue) ->

        target.hasError(newValue.toString().search(regex) != 0)
      validate target()
      target.subscribe(validate)
      target

    @modal = ko.observable(0)
    showSelector = curry (selector) =>

      @modal selector

    @common = common

    @summary = @_createThrottledObservable @model.task, 'summary'
    @description = @_createThrottledObservable @model.task, 'description'
    @color = @_createObservable @model.task, 'color'
    @showColorSelector = => @modal common.COLOR_SELECTOR
    @selectColor = (color) =>

      @modal 0
      @color color

    @story = ko.observable @model.story
    @showStorySelector = => @modal common.STORY_SELECTOR
    @selectStory = (story) =>

      @modal 0
      @model.task.story_id = story._id
      @story story

    @stories = ko.observable [@model.story]
    @model.getStories @model.story.sprint_id, (data) =>

      @stories data

    @initialEstimation = @_createThrottledObservable(@model.task, 'initial_estimation', true)
      .extend({matches: common.TIME_REGEX})

    @sprint = ko.observable @model.sprint
    @startIndex = ko.computed =>

      moment(@sprint().start).format(common.DATE_DB_FORMAT)

    # TODO: to be fetched from datapicker!
    @remainingTimeIndex = ko.observable @model.getDateIndex(@model.sprint)
    @remainingTimeIndexFormatted = ko.computed =>

      @_formatDateIndex @remainingTimeIndex()

    @remainingTime = ko.observable @model.task.remaining_time
    read = =>

      @model._getClosestValueByDateIndex @remainingTime(), @remainingTimeIndex(), @startIndex()
    write = (value) =>
    
      # we need to clone that, b/c otherwise it would not be updated
      object = _.clone @remainingTime()
      object[@remainingTimeIndex()] = parseFloat value, 10
      @remainingTime(object)
    @indexedRemainingTime = @_createIndexedComputed read, write, @, common.TIME_REGEX

    # TODO: to be fetched from datapicker!
    @timeSpentIndex = ko.observable @model.getDateIndex(@model.sprint)
    @timeSpentIndexFormatted = ko.computed =>    

      @_formatDateIndex @timeSpentIndex()
    @timeSpent = ko.observable @model.task.time_spent
    read = =>

      value = @timeSpent()[@timeSpentIndex()]
      if value? then value
      else 0
    write = (value) =>

      object = _.clone @timeSpent()
      object[@timeSpentIndex()] = parseFloat value, 10
      @timeSpent(object) 
    @indexedTimeSpent = @_createIndexedComputed read, write, @, common.TIME_REGEX

  _formatDateIndex: (dateIndex) -> 

    moment(dateIndex).format(common.DATE_DISPLAY_FORMAT)

    #formatDateIndex(remaining_time_index)

  ###
  constructor: (@model, ractiveTemplate) ->

    @view = new TaskView ractiveTemplate, @model
    super(@view, @model)
    @socketio = new TaskSocketIO @view, @model

    $('#summary, #description, #initial_estimation, #remaining_time, #time_spent').each (index, element) => 

      @_setConfirmedValue(element)
    $('#initial_estimation, #remaining_time, #time_spent').data 'validation', (value) -> 

      value.search(/^\d{1,2}(\.\d{1,2}){0,1}$/) == 0

    @_initPopupSelectors()
    @_initDatePickers 

      minDate: new Date @model.sprint.start
      maxDate: new Date ((new Date @model.sprint.start).getTime() + ((@model.sprint.length - 1) * common.MS_TO_DAYS_FACTOR))
  _selectDate: (dateText, inst) =>

    super(dateText, inst)
    dateSelector = $(inst.input).parents('.date-selector')
    id = dateSelector.attr('id')
    @view.set id, dateText
  _setConfirmedValue: (node) ->

    key = node.id 
    if key.match /^remaining_time$|^time_spent$/

      valueObject = @model.get key
      newObject = {}
      for i of valueObject

        newObject[i] = valueObject[i]
      $(node).data 'confirmed_value', newObject
    else

      super node
  _isConfirmedValue: (node) ->

    key = node.id
    value = @view.get "task.#{key}"
    confirmedValue = $(node).data('confirmed_value')
    if key.match /^remaining_time$|^time_spent$/

        # ugly, but is sufficient here.
        JSON.stringify(confirmedValue) == JSON.stringify(value) 
    else 

      confirmedValue == value
  _buildUpdateCall: (node) =>

    call = super node

    key = node.id;
    if key.match /^remaining_time$|^time_spent$/

      #execute that stuff before the update call
      =>
      
        index = $("##{key}_index .selected").data 'date'
        value = parseFloat $(node).val(), 10
        @model.set key, value, index
        call()
    else call
  openSelectorPopup: (ractiveEvent, id) =>

    switch id
      
      when 'story-selector' then @model.getStories @model.story.sprint_id, (data) =>

        @view.set 'stories', data
        @_showPopup(id)
      else @_showPopup(id)
  selectPopupItem: (ractiveEvent, args) =>

    super ractiveEvent, args

    switch args.selector_id

      when 'color-selector' 

        undoValue = @view.get 'color'
        @view.set 'task.color', args.value
        @model.update 'color'

          ,(data) => 

            @view.set 'task._rev', data.rev
          ,(message) =>

            @view.set 'task.color', undoValue
            #TODO: show error
      when 'story-selector' 

        undoValue = @view.get 'task.story_id'
        @view.set 'task.story_id', args.value
        @model.update 'story_id'

          ,(data) => 

            @view.set 'task._rev', data.rev
            @model.getStory data.value, (data) => 

              @view.set 'story', data
          ,(message) =>

            @view.set 'task.story_id', undoValue
            # TODO: show error
  handleButton: (ractiveEvent, action) => 

    super ractiveEvent, action

    switch action

      when 'task_remove' 

        @showError 'Move along. This functionality is not implemented yet.'###