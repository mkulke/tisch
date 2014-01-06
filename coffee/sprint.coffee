class SprintModel extends ParentModel

  getRemainingTime: (storyId, successCb) =>

    $.ajaxq 'client',

      url: "/remaining_time_calculation/#{storyId}"
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->

        if data != null
        
          successCb? data
  getRemainingTimes: (storyIds, successCb) =>

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
  constructor: (@stories, @sprint, @calculations) ->

class SprintViewModel extends ParentViewModel

  _updateSprintModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'sprint', property, value
  _updateStoryModel: (observable, object, property, value) =>

    @_updateModel observable, object, 'story', property, value

  _createObservablesObject: (story) =>

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

  _createSprintNotifications: ->

    update =

      properties: _.chain(@model.sprint).keys().reject((a) -> a[0] == '_').value()
      handler: (data) =>

        @model.sprint._rev = data.rev
        @model.sprint[data.key] = data.value
        @[data.key]?(data.value)
    add = 

      method: 'PUT'
      handler: partial @_addChild, @stories

    [update, add]

  _createStoryNotifications: (observablesObject) =>

    update = 

      id: observablesObject._id
      properties: ['title', 'description', 'color', 'priority']
      handler: (data) =>

        story = observablesObject._js
        story._rev = data.rev
        story[data.key] = data.value
        observablesObject[data.key] data.value

    remove = 

      method: 'DELETE'
      id: observablesObject._id
      handler: =>

        @stories.remove (item) ->

          item._id == observablesObject._id

    [update, remove]

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

      ids = _.pluck @stories(), '_id'
      @model.getRemainingTimes ids, (calculations) =>

        @remainingTimeCalculations calculations

    @start.subscribe updateStats
    @length.subscribe updateStats

    # TODO: if sprint range changes, update calculations

    # stories

    @stories = ko.observableArray _.map @model.stories, @_createObservablesObject
    _.chain(@stories()).pluck('priority').invoke('subscribe', partial(@_sortByPriority, @stories))

    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @model.calculatePriority @stories(), arg.sourceIndex, arg.targetIndex
      arg.item.priority priority

    # button handlers

    showErrorDialog = (message) =>

      @modal 'error-dialog'
      @errorMessage message

    @addStory = =>

      @model.createStory @model.sprint._id, partial(@_addChild, @stories), showErrorDialog

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
          
    # rt specific initializations

    defaults = 

      method: 'POST'
      id: @model.sprint._id

    notifications = @_createSprintNotifications()

    notifications = notifications.concat _.chain(@stories()).map(@_createStoryNotifications).flatten().value()

    _.each notifications, curry2(_.defaults)(defaults)
    
    @stories.subscribe (changes) =>

      for change in changes

        if change.status == 'added'

          observable = @stories()[change.index]
          storyNotifications = @_createStoryNotifications observable, change.index
          _.each notifications, curry2(_.defaults)(defaults)
          socket.registerNotifications storyNotifications
          notifications = notifications.concat storyNotifications
        if change.status == 'deleted'

          socket.unregisterNotifications _.where(notifications, {id: change.value._id})
    , null, 'arrayChange'

    socket = new SocketIO()
    socket.connect (sessionid) =>

      @model.sessionid = sessionid
      socket.registerNotifications notifications 
