describe 'model.getIndexDate', ->

  before ->

    @sprint = {start: '2013-01-01', length: 7}
    @clock = sinon.useFakeTimers(new Date('2013-01-08').getTime())
  after ->

    @clock.restore()
  it 'should return the last date index of the sprint, if the current date is after the sprint', ->

    indexDate = model.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-07'
  it 'should return the first date index of the sprint, if the current date is before the sprint', ->

    @clock = sinon.useFakeTimers(new Date('2012-12-01').getTime())
    indexDate = model.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-01'
  it 'should return the current date, if it is within the sprint range', ->

    @clock = sinon.useFakeTimers(new Date('2013-01-03').getTime())
    indexDate = model.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-03'
  it 'should return a formatted date, when requested', ->

    indexDate = model.getIndexDate(@sprint, true)
    assert.equal indexDate, '01/03/2013'

describe 'model.getDateIndexedValue', ->

  before ->

    model.sprint = {start: '2013-01-01'}
    @map = 

      initial: 10
      '2013-01-03': 7.5
      '2013-01-05': 3
      '2013-01-07': 0
  it 'should return the value for an existing date entry', ->

    value = model.getDateIndexedValue(@map, '2013-01-03')
    assert.equal value, 7.5
  it 'should return 0 for a non-existing date', ->

    value = model.getDateIndexedValue(@map, '2013-01-06')
    assert.equal value, 0
  it 'should return the value of a date entry before it for a non-existing date, when called with inherited=true', ->

    value = model.getDateIndexedValue(@map, '2013-01-06', true)
    assert.equal value, 3
  it 'should return the initial value for a non-existing date with no entry before it, when called with inherited=true', ->

    value = model.getDateIndexedValue(@map, '2013-01-02', true)
    assert.equal value, 10
  it 'should return the last date entry for a date after the sprint, when called with inherited=true', ->

    value = model.getDateIndexedValue(@map, '2013-01-08', true)
    assert.equal value, 0
  it 'should return the initial entry for a date before the sprint, when called with inherited=true', ->

    value = model.getDateIndexedValue(@map, '2012-12-01', true)
    assert.equal value, 10

describe 'model.requestUpdate', ->

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

		#ractive.set.restore()
		@xhr.restore()
	it 'should issue an ajax POST request', ->

    @successCb = sinon.spy()
    model.requestUpdate 'summary', 'New summary', @successCb
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/task/abc'
    assert.equal request.method, 'POST'
    assert.equal request.requestBody, '{"key":"summary","value":"New summary"}'
    assert.equal request.requestHeaders.rev, 45
  ###
	it 'should update the view', ->

    assert.equal @requests.length, 1
    request = @requests[0]
    sinon.stub ractive, 'set'
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert ractive.set.calledWith('task._rev', 46), 'revision not set (correctly)'
    assert ractive.set.calledWith('task.summary', 'New summary'), 'summary not set (correctly)'
  ###
  it 'should execute a success callback', ->

    assert.equal @requests.length, 1
    request = @requests[0]
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert @successCb.calledOnce, 'success callback not called (once)'
  it 'should execute an undo callback', ->

    undoCb = sinon.spy()
    model.requestUpdate 'summary', 'New summary', undefined, undoCb
    assert.equal @requests.length, 2
    request = @requests[1]
    request.respond 500, {'Content-Type': 'text/plain'}, 'An error'
    assert undoCb.calledOnce, 'undo callback not called (once)'

describe 'model.reloadStory', ->

  before ->

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
  after -> 

    @xhr.restore()
  it 'should issue a GET ajax request', ->

    successCb = sinon.spy()
    model.reloadStory 'def', successCb
    assert.equal @requests.length, 1
    request = @requests[0]
    assert.equal request.url, '/story/def'
    assert.equal request.method, 'GET'
  it 'should exectua a success callback', ->

    @requests[0].respond 200, {'Content-Type': 'application/json'}, '{"_id":"not an actual story"}'
    assert @successCb.calledOnce, 'success callback not called (once)'

describe 'model.reloadStories', ->

  before ->

    model.init {

      story_id: 'b'
    }, {}

    @xhr = sinon.useFakeXMLHttpRequest()
    @requests = []
    @xhr.onCreate = (req) => @requests.push req
  after -> 

    #ractive.get.restore()
    #ractive.set.restore()
    @xhr.restore()
  it 'should issue a GET ajax request', ->

    #sinon.stub ractive, 'get', -> [{_id: 'a', sprint_id: 'x'}, {_id: 'b', sprint_id: 'y'}]
    model.reloadStories 'y'
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

describe 'viewModel.triggerUpdate', ->

  before ->

    model.init {summary: 'xyz'}, {}
    @ractiveEvent = {

      node: {localName: 'input', id: 'summary'}
      original: {which: 13, preventDefault: ->}
    }
    sinon.stub @ractiveEvent.original, 'preventDefault'
    @clock = sinon.useFakeTimers()

    $('body').append '<input id="with_validation"/>'
    $('#with_validation').data('validation', (value) -> return false)
  after -> 

    @clock.restore()
    model.requestUpdate.restore()
    $('#with_validation').remove()
  it 'should prevent a submit action on input fields when return is pressed', ->
  
    sinon.stub model, 'requestUpdate'
    viewModel.triggerUpdate(@ractiveEvent)
    assert @ractiveEvent.original.preventDefault.calledOnce, 'preventDefault not called'
  it 'should call model.requestUpdate', ->
  
    assert model.requestUpdate.calledWith('summary', 'xyz'), 'requestUpdate not called with the correct arguments'
  it 'should call model.requestUpdate after 1500ms when called with delay=true', ->
  
    model.requestUpdate.reset()
    viewModel.triggerUpdate(@ractiveEvent, true)
    @clock.tick 1500
    assert model.requestUpdate.calledWith('summary', 'xyz'), 'requestUpdate not called after 1500ms with the correct arguments'
  it 'should not call model.requestUpdate when the node has a validation which fails' , ->

    @ractiveEvent.node = $('#with_validation').get 0
    model.requestUpdate.reset()
    viewModel.triggerUpdate(@ractiveEvent)
    assert model.requestUpdate.notCalled, 'requestUpdate has been called, although it should not have been called'

describe 'viewModel.selectPopupItem', ->

  before ->

    sinon.stub ractive, 'set'

  after ->

    model.requestUpdate.restore()
    model.reloadStory.restore()
    ractive.set.restore()

  it 'should call model.requestUpdate when the popup is a color selector', ->

    sinon.stub model, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'blue'}
    viewModel.selectPopupItem {}, {selector_id: 'color-selector', value: 'blue'}
    assert model.requestUpdate.calledWith 'color', 'blue'
    assert ractive.set.calledTwice, 'ractive is not called twice'

  it 'should set the ractive rev and value after a successful request', ->

    assert ractive.set.calledTwice, 'ractive is not called twice'    

  it 'should call model.requestUpdate and model.reloadStory when the popup is a story selector', ->

    ractive.set.reset()
    model.requestUpdate.restore()
    sinon.stub model, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'abc'}
    sinon.stub model, 'reloadStory', (value, successCb) -> successCb 'stub' 
    viewModel.selectPopupItem {}, {selector_id: 'story-selector', value: 'abc'}
    assert model.requestUpdate.calledWith 'story_id', 'abc'
    assert model.reloadStory.calledWith('abc'), 'reloadStory not called with the correct arguments'

  it 'should set the ractive rev, value and story after successful requests', ->

    assert ractive.set.calledThrice, 'ractive is not called three times'

describe 'viewModel.selectPopupItem', ->

  before ->

    model.story = {sprint_id: 'abc'}
    sinon.stub ractive, 'set'
    sinon.stub model, 'reloadStories', (sprintId, successCb) -> successCb 'stub'

  after ->

    model.reloadStories.restore()
    ractive.set.restore()

  it 'should call model.reloadStories when the popup is a story-selector', ->

    viewModel.openSelectorPopup {}, 'story-selector'
    assert model.reloadStories.calledWith('abc'), 'reloadStories not called'

  it 'should set ractive stories with the returned stories on a successful reload', ->

    assert ractive.set.calledWith('stories', 'stub'), 'ractive set not called with the correct arguments'
