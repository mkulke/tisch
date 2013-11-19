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

  _createObservable: (object, property, updateModel) ->

    observable = ko.observable object[property]
    observable.subscribe (value) ->

      if !observable.hasError && object[property] != value
      
        updateModel observable, object, property, value 
    observable

  _createThrottledObservable: (object, property, updateModel, numeric) ->

    instantaneousProperty = ko.observable(object[property])
    observable = ko.computed(instantaneousProperty).extend({throttle: common.KEYUP_UPDATE_DELAY})
    observable.subscribe (value) ->

      if !instantaneousProperty.hasError? || !instantaneousProperty.hasError() 

        value = if numeric? then parseFloat value, 10 else value
        if object[property] != value

          updateModel observable, object, property, value
    instantaneousProperty

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

  constructor: (@model) ->

    ko.extenders.matches = (target, regex) ->

      target.hasError = ko.observable()
      target.validationMessage = ko.observable()

      validate = (newValue) ->

        target.hasError(newValue.toString().search(regex) != 0)
      validate target()
      target.subscribe(validate)
      target

    ko.bindingHandlers.datepicker = 

      init: (element, valueAccessor, allBindingsAccessor) =>

        options =

          inline: true
          showOtherMonths: true
          dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
          nextText: '<div class="arrow right"></div>'
          prevText: '<div class="arrow left"></div>'
          dateFormat: $.datepicker.ISO_8601
          gotoCurrent: true
          minDate: new Date(allBindingsAccessor().datepickerMin)
          maxDate: new Date(allBindingsAccessor().datepickerMax)
          onSelect: (dateText, inst) => 

            @modal null
            observable = valueAccessor()
            observable(dateText)
        $(element).datepicker(options)
      update: (element, valueAccessor, allBindingsAccessor) ->

        value = ko.utils.unwrapObservable valueAccessor()
        dateValue = $(element).datepicker().val()
        if value? && value != dateValue

          $(element).datepicker 'setDate', value
        min = allBindingsAccessor().datepickerMin

        if moment($(element).datepicker('option', 'minDate')).format(common.DATE_DB_FORMAT) != allBindingsAccessor().datepickerMin

          $(element).datepicker('option', 'minDate', new Date(allBindingsAccessor().datepickerMin))
        if moment($(element).datepicker('option', 'maxDate')).format(common.DATE_DB_FORMAT) != allBindingsAccessor().datepickerMax

          $(element).datepicker('option', 'maxDate', new Date(allBindingsAccessor().datepickerMax))

    @common = common

    @modal = ko.observable null
    showSelector = curry (selector) =>

      @modal selector

    # we need that recalculation, so the footer stays on bottom even
    # with the absolute positionen popups.  
    @modal.subscribe (value) ->

      if value?

        contentHeight = $('#content').height()
        popupHeight = $("##{value} .content").height()
        footerHeight = $("#button-bar").height()
        popupTop = $("##{value}").position()?.top

        if (popupTop + popupHeight) > (contentHeight + footerHeight)

          $('#content').css 'height', popupTop + popupHeight - footerHeight
      else

        $('#content').css 'height', 'auto'

    @cancelPopup = (data, event) =>

      if event.keyCode == 27 && @modal != null

        @modal null

    @errorMessage = ko.observable()
    @confirmError = => 

      @modal null
 
    updateModel = (observable, object, property, value) =>

      oldValue = object[property]
      object[property] = value
      @model.update property, null, (message) =>

        object[property] = oldValue
        observable(oldValue)
        @modal 'error-dialog'
        @errorMessage message      

    #summary

    @summary = @_createThrottledObservable @model.task, 'summary', updateModel
    
    #description

    @description = @_createThrottledObservable @model.task, 'description', updateModel
    
    #color

    @color = @_createObservable @model.task, 'color', updateModel
    @showColorSelector = => @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # story_id

    @stories = ko.observable [@model.story]
    @model.getStories @model.story.sprint_id, (data) =>

      @stories data

    @storyId = @_createObservable @model.task, 'story_id', updateModel
    @storyIdFormatted = ko.computed =>

      story = _.find @stories(), (story) =>

        story._id == @storyId()
      story?.title

    @showStorySelector = => @modal 'story-selector'
    @selectStory = (story) =>

      @modal null
      @storyId story._id

    # initial_estimation

    @initialEstimation = @_createThrottledObservable(@model.task, 'initial_estimation', updateModel, true)
      .extend({matches: common.TIME_REGEX})

    # sprint specific observables

    @sprintStart = ko.observable @model.sprint.start
    @sprintLength = ko.observable @model.sprint.length
    @startIndex = ko.computed =>

      moment(@sprintStart()).format(common.DATE_DB_FORMAT)
    @endIndex = ko.computed =>

      moment(@sprintStart()).add('days', @sprintLength() - 1).format(common.DATE_DB_FORMAT)

    # shared write curry for indexed properties (remaining_time & time_spent)

    writeIndexed = curry (property, observableObject, observableIndex, value) =>

      # we need to clone the obj, b/c otherwise the observable would not be updated
      oldObject = observableObject()
      object = _.clone oldObject
      object[observableIndex()] = parseFloat value, 10
      if !_.isEqual(oldObject, object)
      
        observableObject(object)   
        @model.task[property] = object
        @model.update property, null, (message) =>

          @model.task[property] = oldObject
          observableObject(oldObject)
          @modal 'error-dialog'
          @errorMessage message

    # remaining_time   

    @showRemainingTimeDatePicker = => @modal 'remaining_time-index'

    @remainingTimeIndex = ko.observable @model.getDateIndex(@model.sprint)
    @remainingTimeIndexFormatted = ko.computed =>

      @_formatDateIndex @remainingTimeIndex()

    @remainingTime = ko.observable @model.task.remaining_time

    readRemainingTime = =>

      @model._getClosestValueByDateIndex @remainingTime(), @remainingTimeIndex(), @startIndex()
    @indexedRemainingTime = @_createIndexedComputed readRemainingTime, writeIndexed('remaining_time', @remainingTime, @remainingTimeIndex), @

    # time_spent

    @timeSpentIndex = ko.observable @model.getDateIndex(@model.sprint)
    @timeSpentIndexFormatted = ko.computed =>    

      @_formatDateIndex @timeSpentIndex()

    @showTimeSpentDatePicker = => @modal 'time_spent-index'

    @timeSpent = ko.observable @model.task.time_spent
    @timeSpent.subscribe (value) ->

      console.log "time_spent: #{JSON.stringify(value)}"

    readTimeSpent = =>

      value = @timeSpent()[@timeSpentIndex()]
      if value? then value else 0
    @indexedTimeSpent = @_createIndexedComputed readTimeSpent, writeIndexed('time_spent', @timeSpent, @timeSpentIndex), @

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