class TaskSocketIO extends SocketIO
  
  _onUpdate: (data) =>

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
    @showColorSelector = => 

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # story_id

    @stories = ko.observable [@model.story]

    @storyId = @_createObservable @model.task, 'story_id', updateModel
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

    @initialEstimation = @_createThrottledObservable(@model.task, 'initial_estimation', updateModel, true)
      .extend({matches: common.TIME_REGEX})

    # sprint specific observables

    @sprint = ko.observable @model.sprint
    @sprintUrl = ko.computed =>

      '/sprint/' + @sprint()._id
    @startIndex = ko.computed =>

      moment(@sprint().start).format(common.DATE_DB_FORMAT)
    @endIndex = ko.computed =>

      moment(@sprint().start).add('days', @sprint().length - 1).format(common.DATE_DB_FORMAT)

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
        @model.update property, null, (message) =>

          @model.task[property] = oldObject
          observableObject(oldObject)
          @modal 'error-dialog'
          @errorMessage message

    formatDateIndex = (dateIndex) -> 

      moment(dateIndex).format(common.DATE_DISPLAY_FORMAT)

    # remaining_time   

    @showRemainingTimeDatePicker = => @modal 'remaining_time-index'

    @remainingTimeIndex = ko.observable @model.getDateIndex(@model.sprint)
    @remainingTimeIndexFormatted = ko.computed =>

      formatDateIndex @remainingTimeIndex()

    @remainingTime = ko.observable @model.task.remaining_time

    readRemainingTime = =>

      @model._getClosestValueByDateIndex @remainingTime(), @remainingTimeIndex(), @startIndex()
    @indexedRemainingTime = @_createIndexedComputed readRemainingTime, writeIndexed('remaining_time', @remainingTime, @remainingTimeIndex), @

    # time_spent

    @timeSpentIndex = ko.observable @model.getDateIndex(@model.sprint)
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