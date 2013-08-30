describe 'controller.requestUpdate', ->

	requests = xhr = null

	before -> 

		model.init {

			_id: 'abc'
			_rev: 45
			summary: 'Old summary'
		}, {}

		xhr = sinon.useFakeXMLHttpRequest()
		requests = []
		xhr.onCreate = (req) -> requests.push req
	after -> 

		view.set.restore()
		xhr.restore()
	it 'should issue an ajax POST request', ->

    controller.requestUpdate 'summary', 'New summary'

    assert.equal requests.length, 1
    request = requests[0]
    assert.equal request.url, '/task/abc'
    assert.equal request.method, 'POST'
    assert.equal request.requestBody, '{"key":"summary","value":"New summary"}'
    assert.equal request.requestHeaders.rev, 45
	it 'should update the view', ->

    assert.equal requests.length, 1
    request = requests[0]
    sinon.stub view, 'set'
    request.respond 200, {'Content-Type': 'application/json'}, '{"rev":46,"id":"abc","key":"summary","value":"New summary"}'
    assert view.set.calledWith('task._rev', 46), 'revision not set (correctly)'
    assert view.set.calledWith('task.summary', 'New summary'), 'summary not set (correctly)'
