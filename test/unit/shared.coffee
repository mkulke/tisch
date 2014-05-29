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

    @xhr.restore()
  it 'should issue a GET ajax request', ->

    @model.getStories 'y', 'z', ->
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/stories'
    assert.equal request.method, 'GET'
    assert.equal request.requestHeaders.parent_id, 'y'
    assert.equal request.requestHeaders.sort_by, 'z'
  it 'should call a success Callback', ->

    @requests[0].respond 200, {'Content-Type': 'application/json'}, '[{"_id":"a"},{"_id":"b"},{"_id":"c"}]'
    assert @successCb.calledOnce, 'success callback not called (once)'

  ###
  it 'should update the view with the response', ->

    sinon.stub ractive, 'set'
    @requests[0].respond 200, {'Content-Type': 'application/json'}, '[{"_id":"a"},{"_id":"b"},{"_id":"c"}]'
    assert ractive.set.calledWith('stories', [{_id: 'a'}, {_id: 'b'}, {_id: 'c'}]), 'stories not set (correctly)'
  ###

describe 'Model.buildSprintRange', ->

  before ->

    @model = new Model
  it 'should return a calculated sprint range object', ->

    range = @model.buildSprintRange '2010-01-01T00:00:00.000Z', 7
    assert.equal range.start, '2010-01-01'
    assert.equal range.end, '2010-01-07'

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

    