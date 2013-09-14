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
    @model.update 'summary', @successCb
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
    @model.update 'summary', undefined, undoCb
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
    @model.getStories 'y'
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

describe 'ViewModel.triggerUpdate', ->

  before ->

    @ractiveEvent = {

      node: {localName: 'input', id: 'summary'}
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
  it 'should prevent a submit action on input fields when return is pressed', ->
  
    sinon.stub @model, 'update'
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @ractiveEvent.original.preventDefault.calledOnce, 'preventDefault not called'
  it 'should call Model.update', ->
  
    assert @model.update.calledWith('summary'), 'update not called with the correct arguments'
  it 'should call Model.update after 1500ms when called with delay=true', ->
  
    @model.update.reset()
    @viewModel.triggerUpdate(@ractiveEvent, true)
    @clock.tick 1500
    assert @model.update.calledWith('summary'), 'update not called after 1500ms with the correct arguments'
  it 'should not call Model.update when the node has a validation which fails' , ->

    @ractiveEvent.node = $('#with_validation').get 0
    @model.update.reset()
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @model.update.notCalled, 'update has been called, although it should not have been called'
    