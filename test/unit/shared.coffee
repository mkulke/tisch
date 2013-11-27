describe 'Model.update', ->

  before -> 

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
    #@taskModel = new TaskModel {_id: 'abc', _rev: 45, summary: 'Old summary'}, {}, {}
    @model = new Model
    @model.type = 'sometype'
    @model['sometype'] = {_id: 'abc', _rev: 45, summary: 'New summary'}
  after -> 

    @xhr.restore()
  it 'should issue an ajax POST request', ->

    @successCb = sinon.spy()
    @model.update @model[@model.type], 'summary', @model.type, @successCb
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/sometype/abc'
    assert.equal request.method, 'POST'
    assert.equal request.requestBody, '{"key":"summary","value":"New summary"}'
    assert.equal request.requestHeaders.rev, 45
  ###
  it 'should update the view', ->

    assert.equal @requests.length, 1
    request = @requests[0]
    sinon.stub view, 'set'
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert view.set.calledWith('task._rev', 46), 'revision not set (correctly)'
    assert view.set.calledWith('task.summary', 'New summary'), 'summary not set (correctly)'
  ###
  it 'should execute a success callback', ->

    assert.equal @requests.length, 1
    request = @requests[0]
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert @successCb.calledOnce, 'success callback not called (once)'
  it 'should execute an undo callback', ->

    undoCb = sinon.spy()
    @model.update @model[@model.type], 'summary', @model.type, undefined, undoCb
    assert.equal @requests.length, 2
    request = @requests[1]
    request.respond 500, {'Content-Type': 'text/plain'}, 'An error'
    assert undoCb.calledOnce, 'undo callback not called (once)'

describe 'Model.getStory', ->

  before ->

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
    @model = new Model
  after -> 

    @xhr.restore()
  it 'should issue a GET ajax request', ->

    successCb = sinon.spy()
    @model.getStory 'def', successCb
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/story/def'
    assert.equal request.method, 'GET'
  it 'should exectua a success callback', ->

    @requests[0].respond 200, {'Content-Type': 'application/json'}, '{"_id":"not an actual story"}'
    assert @successCb.calledOnce, 'success callback not called (once)'

describe 'Model.getStories', ->

  before ->

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
    @model = new Model
  after -> 

    #ractive.get.restore()
    #ractive.set.restore()
    @xhr.restore()
  it 'should issue a GET ajax request', ->

    #sinon.stub ractive, 'get', -> [{_id: 'a', sprint_id: 'x'}, {_id: 'b', sprint_id: 'y'}]
    @model.getStories 'y', ->
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/story'
    assert.equal request.method, 'GET'
    assert.equal request.requestHeaders.parent_id, 'y'
  it 'should call a success Callback', ->

    @requests[0].respond 200, {'Content-Type': 'application/json'}, '[{"_id":"a"},{"_id":"b"},{"_id":"c"}]'
    assert @successCb.calledOnce, 'success callback not called (once)'

  ###
  it 'should update the view with the response', ->

    sinon.stub ractive, 'set'
    @requests[0].respond 200, {'Content-Type': 'application/json'}, '[{"_id":"a"},{"_id":"b"},{"_id":"c"}]'
    assert ractive.set.calledWith('stories', [{_id: 'a'}, {_id: 'b'}, {_id: 'c'}]), 'stories not set (correctly)'
  ###

describe 'Model.getClosestValueByDateIndex', ->

  before ->

    @startIndex = '2013-01-01'
    @model = new Model
    @remainingTime = 

      initial: 10
      '2013-01-03': 7.5
      '2013-01-05': 3
      '2013-01-07': 0
  it 'should return the value for an existing date entry', ->

    value = @model.getClosestValueByDateIndex(@remainingTime, '2013-01-03', @startIndex)
    assert.equal value, 7.5
  it 'should return the value of a date entry before it for a non-existing date', ->

    value = @model.getClosestValueByDateIndex(@remainingTime, '2013-01-06', @startIndex)
    assert.equal value, 3
  it 'should return the initial value for a non-existing date with no entry before it', ->

    value = @model.getClosestValueByDateIndex(@remainingTime, '2013-01-02', @startIndex)
    assert.equal value, 10
  it 'should return the last date entry for a date after the sprint', ->

    value = @model.getClosestValueByDateIndex(@remainingTime, '2013-01-08', @startIndex)
    assert.equal value, 0
  it 'should return the initial entry for a date before the sprint', ->

    value = @model.getClosestValueByDateIndex(@remainingTime, '2012-12-01', @startIndex)
    assert.equal value, 10

describe 'Model.buildSprintRange', ->

  before ->

    @model = new Model
  it 'should return a calculated sprint range object', ->

    range = @model.buildSprintRange '2010-01-01T00:00:00.000Z', 7
    assert.equal range.start, '2010-01-01'
    assert.equal range.end, '2010-01-07'

###describe 'ViewModel.triggerUpdate', ->

  before ->

    $('body').append '<input id="summary"/>'
    $('body').append '<input id="with_validation"/>'
    $('#with_validation').data('validation', (value) -> return false)

    @ractiveEvent = {

      node: $('#summary').get(0)
      original: {which: 13, preventDefault: ->}
    }
    sinon.stub @ractiveEvent.original, 'preventDefault'
    @clock = sinon.useFakeTimers()

    $('body').append '<input id="with_validation"/>'
    $('#with_validation').data('validation', (value) -> return false)
    class StubViewModel extends ViewModel

      constructor: ->
    @viewModel = new StubViewModel
    @model = new Model
    @model.type = 'sometype'
    @model.sometype = {summary: 'xyz'}
    @viewModel.model = @model
    @viewModel.view = {set: (->), get: -> 'New summary'}
  after -> 

    @clock.restore()
    @model.update.restore()
    $('#with_validation').remove()
    $('#summary').remove()
  it 'should prevent a submit action on input fields when return is pressed', ->
  
    sinon.stub @model, 'update'
    @viewModel.triggerUpdate @ractiveEvent
    assert @ractiveEvent.original.preventDefault.calledOnce, 'preventDefault not called'
  it 'should call Model.update after 1500ms', ->
  
    @clock.tick 1500
    assert @model.update.calledWith('summary'), 'update not called after 1500ms with the correct arguments'
  it 'should not call Model.update when the node has a validation which fails' , ->

    @ractiveEvent.node = $('#with_validation').get 0
    @model.update.reset()
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @model.update.notCalled, 'update has been called, although it should not have been called'

describe 'ChildViewModel.triggerUpdate', ->

  before ->

    $('body').append '<input id="summary-0"/>'
    @ractiveEvent = {

      node: $('#summary-0').get(0)
      original: {which: 13, preventDefault: ->}
    }

    class StubViewModel extends ChildViewModel

      constructor: ->
    @viewModel = new StubViewModel
    @model = new Model
    @model.type = 'sometype'
    @model.children = {type: 'childtype', objects: [{ summary: 'xyz'}]}
    @viewModel.model = @model
    @viewModel.view = {set: (->), get: -> 'abc'}
    sinon.stub @model, 'updateChild'
    @clock = sinon.useFakeTimers()
  after -> 

    @clock.restore()
    $('#summary-0').remove()
    @model.updateChild.restore()
  it 'should call Model.updateChild after 1500ms when called and the node id has a child index', ->
  
    @viewModel.triggerUpdate @ractiveEvent
    @clock.tick 1500
    assert @model.updateChild.calledWith('0', 'summary'), 'updateChild not called with the correct arguments'

describe 'ChildViewModel._calculatePriority', ->

  before ->

    class StubViewModel extends ChildViewModel

      constructor: ->
    @viewModel = new StubViewModel
    @model = new Model
    @objects = [{priority: 1}, {priority: 2}, {priority: 3}, {priority: 4.5}]
    @model.children = {type: 'childtype', objects: @objects}
    @viewModel.model = @model
  afterEach ->

    @model.children.objects = [{priority: 1}, {priority: 2}, {priority: 3}, {priority: 4.5}]    

  it 'should return 1.5 when the item before is 1 and the item after is 2', ->
  
    priority = @viewModel._calculatePriority 3, 1
    assert.equal priority, 1.5
  it 'should return 0.5 when it is the first item in the list and the item after is 1', ->
  
    priority = @viewModel._calculatePriority 2, 0
    assert.equal priority, 0.5
  it 'should return 3.75 when the item before is 3 and the item after is 4.5', ->
  
    priority = @viewModel._calculatePriority 0, 2
    assert.equal priority, 3.75
  it 'should return 6 when it is the last item in the list and the item before is 4.5', ->
  
    priority = @viewModel._calculatePriority 2,3
    assert.equal priority, 6

describe 'ChildViewModel._handleSortstop', ->

  before ->

    class StubViewModel extends ChildViewModel

      constructor: ->
      view: {update: (->), set: ->}
    @viewModel = new StubViewModel
    @model = new Model
    @objects = [{priority: 1}, {priority: 2}, {priority: 3}, {priority: 4.5}]
    @model.children = {type: 'childtype', objects: @objects}
    @viewModel.model = @model
    sinon.stub @model, 'updateChild'

  after ->

    @model.updateChild.restore()
  afterEach ->

    @model.children.objects = [{priority: 1}, {priority: 2}, {priority: 3}, {priority: 4.5}]    

  it 'should update item 2 with priority 3.75 when dropped between item 3 and item 4', ->

    @viewModel._handleSortstop 1, 2
    assert.equal @model.children.objects[1].priority, 3.75
    assert @model.updateChild.calledWith(1, 'priority'), 'updateChild not called with the correct arguments'

  it 'should reset the priority of an object, if the update failed', ->

    @model.updateChild.restore()
    sinon.stub @model, 'updateChild', (index, key, successCb, errorCb) -> errorCb('error')
    @viewModel._handleSortstop 1, 2
    assert.equal @model.children.objects[1].priority, 2###

describe 'Chart.calculateChartRange', ->

  before ->

    @chart = new Chart
    @object = 

      a: [

        {date: '2010-02-01', value: 1}
        {date: '2010-02-02', value: 2}
      ]
      b: [

        {date: '2010-01-01', value: 1}
        {date: '2010-01-02', value: 8}
      ]
      c: [

        {date: '2010-03-01', value: 1}
        {date: '2010-03-02', value: 2}
      ]

  it 'should calculate a maximum date', ->

    [yMax, xMin, xMax] = @chart._calculateChartRange @object
    assert.equal moment(xMax).unix(), moment('2010-03-02').unix()
  it 'should calculate a minimum date', ->

    [yMax, xMin, xMax] = @chart._calculateChartRange @object
    assert.equal moment(xMin).unix(), moment('2010-01-01').unix()
  it 'should calculate a maximum value', ->

    [yMax, xMin, xMax] = @chart._calculateChartRange @object
    assert.equal yMax, 8

    