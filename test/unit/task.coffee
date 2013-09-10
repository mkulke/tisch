describe 'TaskModel.getIndexDate', ->

  before ->

    @taskModel = new TaskModel
    @sprint = {start: '2013-01-01', length: 7}
    @clock = sinon.useFakeTimers(new Date('2013-01-08').getTime())
  after ->

    @clock.restore()
  it 'should return the last date index of the sprint, if the current date is after the sprint', ->

    indexDate = @taskModel.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-07'
  it 'should return the first date index of the sprint, if the current date is before the sprint', ->

    @clock = sinon.useFakeTimers(new Date('2012-12-01').getTime())
    indexDate = @taskModel.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-01'
  it 'should return the current date, if it is within the sprint range', ->

    @clock = sinon.useFakeTimers(new Date('2013-01-03').getTime())
    indexDate = @taskModel.getIndexDate(@sprint)
    assert.equal indexDate, '2013-01-03'
  it 'should return a formatted date, when requested', ->

    indexDate = @taskModel.getIndexDate(@sprint, true)
    assert.equal indexDate, '01/03/2013'

describe 'TaskModel.getDateIndexedValue', ->

  before ->

    @taskModel = new TaskModel {}, {}, {start: '2013-01-01'}
    @map = 

      initial: 10
      '2013-01-03': 7.5
      '2013-01-05': 3
      '2013-01-07': 0
  it 'should return the value for an existing date entry', ->

    value = @taskModel.getDateIndexedValue(@map, '2013-01-03')
    assert.equal value, 7.5
  it 'should return 0 for a non-existing date', ->

    value = @taskModel.getDateIndexedValue(@map, '2013-01-06')
    assert.equal value, 0
  it 'should return the value of a date entry before it for a non-existing date, when called with inherited=true', ->

    value = @taskModel.getDateIndexedValue(@map, '2013-01-06', true)
    assert.equal value, 3
  it 'should return the initial value for a non-existing date with no entry before it, when called with inherited=true', ->

    value = @taskModel.getDateIndexedValue(@map, '2013-01-02', true)
    assert.equal value, 10
  it 'should return the last date entry for a date after the sprint, when called with inherited=true', ->

    value = @taskModel.getDateIndexedValue(@map, '2013-01-08', true)
    assert.equal value, 0
  it 'should return the initial entry for a date before the sprint, when called with inherited=true', ->

    value = @taskModel.getDateIndexedValue(@map, '2012-12-01', true)
    assert.equal value, 10

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
    @taskModel = new TaskModel {summary: 'xyz'}
    @viewModel.model = @taskModel
    @viewModel.view = {set: ->}
  after -> 

    @clock.restore()
    @taskModel.requestUpdate.restore()
    $('#with_validation').remove()
  it 'should prevent a submit action on input fields when return is pressed', ->
  
    sinon.stub @taskModel, 'requestUpdate'
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @ractiveEvent.original.preventDefault.calledOnce, 'preventDefault not called'
  it 'should call TaskModel.requestUpdate', ->
  
    assert @taskModel.requestUpdate.calledWith('summary', 'xyz'), 'requestUpdate not called with the correct arguments'
  it 'should call TaskModel.requestUpdate after 1500ms when called with delay=true', ->
  
    @taskModel.requestUpdate.reset()
    @viewModel.triggerUpdate(@ractiveEvent, true)
    @clock.tick 1500
    assert @taskModel.requestUpdate.calledWith('summary', 'xyz'), 'requestUpdate not called after 1500ms with the correct arguments'
  it 'should not call TaskModel.requestUpdate when the node has a validation which fails' , ->

    @ractiveEvent.node = $('#with_validation').get 0
    @taskModel.requestUpdate.reset()
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @taskModel.requestUpdate.notCalled, 'requestUpdate has been called, although it should not have been called'

describe 'ViewModel.selectPopupItem', ->

  before ->

    class StubViewModel extends ViewModel

      constructor: ->

        @view = {set: ->}
    @viewModel = new StubViewModel
    @taskModel = new TaskModel {summary: 'xyz'}
    @viewModel.model = @taskModel
    sinon.stub @viewModel.view, 'set'
  after ->

    @taskModel.requestUpdate.restore()
    @taskModel.getStory.restore()
    @viewModel.view.set.restore()

  it 'should call TaskModel.requestUpdate when the popup is a color selector', ->

    sinon.stub @taskModel, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'blue'}
    @viewModel.selectPopupItem {}, {selector_id: 'color-selector', value: 'blue'}
    assert @taskModel.requestUpdate.calledWith 'color', 'blue'
    assert @viewModel.view.set.calledTwice, 'view is not called twice'

  it 'should set the view rev and value after a successful request', ->

    assert @viewModel.view.set.calledTwice, 'view is not called twice'    

  it 'should call TaskModel.requestUpdate and TaskModel.getStory when the popup is a story selector', ->

    @viewModel.view.set.reset()
    @taskModel.requestUpdate.restore()
    sinon.stub @taskModel, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'abc'}
    sinon.stub @taskModel, 'getStory', (value, successCb) -> successCb 'stub' 
    @viewModel.selectPopupItem {}, {selector_id: 'story-selector', value: 'abc'}
    assert @taskModel.requestUpdate.calledWith 'story_id', 'abc'
    assert @taskModel.getStory.calledWith('abc'), 'getStory not called with the correct arguments'

  it 'should set the view rev, value and story after successful requests', ->

    assert @viewModel.view.set.calledThrice, 'view is not called three times'

describe 'ViewModel.openSelectorPopup', ->

  before ->

    class StubViewModel extends ViewModel

      constructor: ->

        @view = {set: ->}
    @viewModel = new StubViewModel
    @taskModel = new TaskModel({}, {sprint_id: 'abc'})
    @viewModel.model = @taskModel 
    sinon.stub @viewModel.view, 'set'
    sinon.stub @taskModel, 'getStories', (sprintId, successCb) -> successCb 'stub'

  after ->

    @taskModel.getStories.restore()
    @viewModel.view.set.restore()

  it 'should call TaskModel.getStories when the popup is a story-selector', ->

    @viewModel.openSelectorPopup {}, 'story-selector'
    assert @taskModel.getStories.calledWith('abc'), 'getStories not called'

  it 'should set view stories with the returned stories on a successful reload', ->

    assert @viewModel.view.set.calledWith('stories', 'stub'), 'view set not called with the correct arguments'
