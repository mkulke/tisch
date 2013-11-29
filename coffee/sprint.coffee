class SprintSocketIO extends SocketIO

  _verifyCalculations: (storyId) =>

    object = _.find @viewModel.stories(), (story) =>

      story._id == storyId
    if object?

      @model.getRemainingTime object._id, (data) =>

        @_updateObservableProperty @viewModel.remainingTimeCalculations, object._id, data

  _onUpdate: (data) =>

    if data.id == @model.sprint._id

      @model.sprint._rev = data.rev
      @model.sprint[data.key] = data.value
      @viewModel[data.key]?(data.value)

    # object of story observables
    object = _.find @viewModel.stories(), (story) => 

      story._id == data.id
    if object?
  
      story = object._js 
      story._rev = data.rev
      story[data.key] = data.value
      object[data.key]?(data.value)

    # object of task observables
    object = _.find @viewModel.stories(), (story) => 

      story._id == data.parent_id
    if object?

      @_verifyCalculations object._id

  _onAdd: (data) =>

    data.story_id && @_verifyCalculations data.story_id
  _onRemove: (data) =>

    data.story_id && @_verifyCalculations data.story_id
class SprintModel extends ParentModel

  getRemainingTime: (storyId, successCb) =>

    $.ajaxq 'client',

      url: "/remaining_time_calculation/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->

        successCb? data
  getRemainingTimes: (successCb) =>

    storyIds = _.pluck @children.objects, '_id'

    gets = []
    remainingTimes = {}
    _.each storyIds, (storyId) =>

      gets.push $.ajaxq 'client',

        url: "/remaining_time_calculation/#{storyId}"
        type: 'GET'
        dataType: 'json'
        success: (data, textStatus, jqXHR) ->

          remainingTimes[storyId] = data
    $.when.apply($, gets).then ->

      successCb? remainingTimes

  type: 'sprint'
  constructor: (stories, @sprint, @calculations) ->

  	@children = {type: 'story', objects: stories}

class SprintViewModel extends ParentViewModel

  _updateSprintModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'sprint', property, value
  _updateStoryModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'story', property, value

  constructor: (@model) ->

    super(@model)

    # confirmation dialog specific

    @confirmMessage = ko.observable()
    @cancel = =>

      @modal null
    @confirm = ->

    # title

    @title = @_createThrottledObservable @model.sprint, 'title', @_updateSprintModel

    # description

    @description = @_createThrottledObservable @model.sprint, 'description', @_updateSprintModel

    # color

    @color = @_createObservable @model.sprint, 'color', @_updateSprintModel
    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @color color

    # start

    @showStartDatePicker = => 

      @modal 'start-selector'
    @start = @_createObservable @model.sprint, 'start', @_updateSprintModel
    @startDate = ko.computed

      read: =>

        new Date(@start())
      write: (value) =>

        # the datepicker binding returns a xxxx-xx-xx string, we need a Date, tho.
        @start new moment(value).toDate()
      owner: @
    @startFormatted = ko.computed =>

      moment(@start()).format(common.DATE_DISPLAY_FORMAT)

    # length

    @showLengthDatePicker = => 

      @modal 'length-selector'
    @length = @_createObservable @model.sprint, 'length', @_updateSprintModel
    @lengthDate = ko.computed

      read: =>

        moment(@start()).add('days', @length() - 1).toDate()
      write: (value) =>

        start = moment @start()
        # since @start() as 'XXXX-XX-XXT00:00:00.000Z' is parsed w/o timezone offset, and value
        # is 'XXXX-XX-XX' has the timezone offset, we need to use moment.utc here to calculate
        # the delta here.
        end = moment.utc value
        @length moment.duration(end - start).days() + 1
    @endFormatted = ko.computed =>

      moment(@lengthDate()).format(common.DATE_DISPLAY_FORMAT)

    # calculations

    @remainingTimeCalculations = ko.observable @model.calculations.remaining_time

    updateStats = =>

      @model.getRemainingTimes (calculations) =>

        @remainingTimeCalculations calculations

    @start.subscribe updateStats
    @length.subscribe updateStats

    # TODO: if sprint range changes, update calculations

    # stories

    createObservablesObject = (story) =>

      _id: story._id
      title: @_createThrottledObservable story, 'title', @_updateStoryModel
      description: @_createThrottledObservable story, 'description', @_updateStoryModel
      color: @_createObservable story, 'color', @_updateStoryModel
      priority: @_createObservable story, 'priority', @_updateStoryModel
      _remaining_time: ko.computed =>

        if @remainingTimeCalculations()[story._id]? 

          @remainingTimeCalculations()[story._id]
        else

          null
      _url: '/story/' + story._id
      _js: story

    stories = _.map @model.children.objects, createObservablesObject
    _.each stories, (story) =>

      story.priority.subscribe =>

        @stories.sort (a, b) =>

          a.priority() - b.priority()

    @stories = ko.observableArray stories
    @stories.subscribe (changes) =>

      for change in changes

        if change.status == 'added'

          storyObservable = @stories()[change.index]
          @model.children.objects.splice change.index, 0, storyObservable._js
        else if change.status == 'deleted'

          @model.children.objects.splice change.index, 1
    , null, 'arrayChange'

    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @model.calculatePriority @stories(), arg.sourceIndex, arg.targetIndex
      arg.item.priority priority

    # button handlers

    showErrorDialog = (message) =>

      @modal 'error-dialog'
      @errorMessage message

    @addStory = =>

      @model.createStory @model.sprint._id

        , (story) => 
        
          observableObject = createObservablesObject story
          @stories.push observableObject
          # TODO: sort after push?
        , showErrorDialog

    @removeStory = (storyObservable) =>

      @modal 'confirm-dialog'
      # TODO: i18n
      @confirmMessage 'Are you sure? The story and the tasks assigned to it will be permanently removed.'
      @confirm = =>

        @modal null
        story = storyObservable._js
        @model.removeStory story

          , =>

            @stories.remove (item) =>

              item._id == story._id
          , showErrorDialog