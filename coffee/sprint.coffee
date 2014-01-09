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

  _createObservables: (story) =>

    updateModel = partial @_updateModel, 'story'
    createObservable_ = partial @_createObservable3, updateModel, story

    writables = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'priority'}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}
    
    _id: story._id
    title: writables.title
    description: writables.description
    color: ko.observable story.color
    priority: writables.priority
    _remaining_time: ko.computed =>

      @remainingTimeCalculations()[story._id]
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

    # TODO: use mixins
    # set global options for jquery ui sortable

    ko.bindingHandlers.sortable.options = 

      tolerance: 'pointer'
      delay: 150
      cursor: 'move'
      containment: 'ul#well'
      handle: '.header'

    # confirmation dialog specific

    @confirmMessage = ko.observable()
    @cancel = =>

      @modal null
    @confirm = ->

    # test

    updateModel = partial @_updateModel, 'sprint'
    createObservable_ = partial @_createObservable3, updateModel, @model.sprint

    @writables = _.reduce [

      {name: 'title', throttled: true}
      {name: 'description', throttled: true}
      {name: 'color'}
      {name: 'start'}
      {name: 'length'}
    ], (object, property) ->

      object[property.name] = createObservable_ property.name, _.omit(property, 'name'); object
    , {}

    @showColorSelector = =>

      @modal 'color-selector'
    @selectColor = (color) =>

      @modal null
      @writables.color color

    # start

    @showStartDatePicker = => 

      @modal 'start-selector'

    @startDate = ko.computed

      read: =>

        new Date(@writables.start())
      write: (value) =>

        # the datepicker binding returns a xxxx-xx-xx string, we need a Date, tho.
        @writables.start new moment(value).toDate()
      owner: @
    @startFormatted = ko.computed =>

      moment(@writables.start()).format(common.DATE_DISPLAY_FORMAT)

    # length

    @showLengthDatePicker = => 

      @modal 'length-selector'
    @lengthDate = ko.computed

      read: =>

        moment(@writables.start()).add('days', @writables.length() - 1).toDate()
      write: (value) =>

        start = moment @writables.start()
        # since @start() as 'XXXX-XX-XXT00:00:00.000Z' is parsed w/o timezone offset, and value
        # is 'XXXX-XX-XX' has the timezone offset, we need to use moment.utc here to calculate
        # the delta here.
        end = moment.utc value
        @writables.length moment.duration(end - start).days() + 1
    @endFormatted = ko.computed =>

      moment(@lengthDate()).format(common.DATE_DISPLAY_FORMAT)

    # calculations

    @remainingTimeCalculations = ko.observable @model.calculations.remaining_time

    updateStats = =>

      ids = _.pluck @stories(), '_id'
      @model.getRemainingTimes ids, (calculations) =>

        @remainingTimeCalculations calculations

    @writables.start.subscribe updateStats
    @writables.length.subscribe updateStats

    # TODO: if sprint range changes, update calculations

    # stories

    @stories = ko.observableArray _.map @model.stories, @_createObservables
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
