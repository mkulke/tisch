describe 'controller.requestUpdate', ->

	before -> 

		model.init {

			_id: 'abc'
			_rev: 45
			summary: 'Old summary'
		}, {}

		@xhr = sinon.useFakeXMLHttpRequest()
		@requests = []
		@xhr.onCreate = (req) => @requests.push req
	after -> 

		view.set.restore()
		@xhr.restore()
	it 'should issue an ajax POST request', ->

    @successCb = sinon.spy()
    controller.requestUpdate 'summary', 'New summary', @successCb
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/task/abc'
    assert.equal request.method, 'POST'
    assert.equal request.requestBody, '{"key":"summary","value":"New summary"}'
    assert.equal request.requestHeaders.rev, 45
	it 'should update the view', ->

    assert.equal @requests.length, 1
    request = @requests[0]
    sinon.stub view, 'set'
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert view.set.calledWith('task._rev', 46), 'revision not set (correctly)'
    assert view.set.calledWith('task.summary', 'New summary'), 'summary not set (correctly)'
  it 'should execute a success callback', ->

    assert @successCb.calledOnce, 'success callback not called (once)'
  it 'should execute an undo callback', ->

    undoCb = sinon.spy()
    controller.requestUpdate 'summary', 'New summary', undefined, undoCb
    assert.equal @requests.length, 2
    request = @requests[1]
    request.respond 500, {'Content-Type': 'text/plain'}, 'An error'
    assert undoCb.calledOnce, 'undo callback not called (once)'

describe 'controller.reloadStory', ->

  before ->

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
  after -> 

    view.set.restore()
    @xhr.restore()
  it 'should issue a GET ajax request', ->

    controller.reloadStory 'def'
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/story/def'
    assert.equal request.method, 'GET'
  it 'should update the view with the response', ->

    sinon.stub view, 'set'
    @requests[0].respond 200, {'Content-Type': 'application/json'}, '{"_id":"not an actual story"}'
    assert view.set.calledWith('story', {_id: 'not an actual story'}), 'story not set (correctly)'

describe 'controller.populateStorySelector', ->

  before ->

    model.init {

      story_id: 'b'
    }, {}

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
  after -> 

    view.get.restore()
    @xhr.restore()
  it 'should issue a GET ajax request', ->

    sinon.stub view, 'get', -> [{_id: 'a', sprint_id: 'x'}, {_id: 'b', sprint_id: 'y'}]
    controller.populateStorySelector()
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/story'
    assert.equal request.method, 'GET'
    assert.equal request.requestHeaders.parent_id, 'y'
  it 'should update the view with the response', ->

    sinon.stub view, 'set'
    @requests[0].respond 200, {'Content-Type': 'application/json'}, '[{"_id":"a"},{"_id":"b"},{"_id":"c"}]'
    assert view.set.calledWith('stories', [{_id: 'a'}, {_id: 'b'}, {_id: 'c'}]), 'stories not set (correctly)'

describe 'view.triggerUpdateTimer, view.commitUserInput', ->

  before ->

    model.init {summary: 'xyz'}, {}
    @event = {

      node: {localName: 'input', id: 'summary'}
      original: {which: 13, preventDefault: ->}
    }
    sinon.stub @event.original, 'preventDefault'
    @clock = sinon.useFakeTimers()
  after -> 

    @event.original.preventDefault.restore()
    @clock.restore()
    controller.requestUpdate.restore()
  it 'should prevent a submit action on input fields when return is pressed', ->

    sinon.stub controller, 'requestUpdate'
    view.triggerUpdateTimer(@event)
    assert view.set.calledOnce, 'preventDefault not called'
  it 'should call commitUserInput (and thus controller.requestUpdate) after 1500ms', ->
    @clock.tick 1500
    assert controller.requestUpdate.calledWith('summary', 'xyz'), 'requestUpdate not called after 1500ms with the correct arguments'