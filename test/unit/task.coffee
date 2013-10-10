describe 'TaskModel.getDateIndex', ->

  before ->

    @taskModel = new TaskModel
    @sprint = {start: '2013-01-01', length: 7}
    @clock = sinon.useFakeTimers(new Date('2013-01-08').getTime())
  after ->

    @clock.restore()
  it 'should return the last date index of the sprint, if the current date is after the sprint', ->

    indexDate = @taskModel.getDateIndex(@sprint)
    assert.equal indexDate, '2013-01-07'
  it 'should return the first date index of the sprint, if the current date is before the sprint', ->

    @clock = sinon.useFakeTimers(new Date('2012-12-31').getTime())
    indexDate = @taskModel.getDateIndex(@sprint)
    assert.equal indexDate, '2013-01-01'
  it 'should return the current date, if it is within the sprint range', ->

    @clock = sinon.useFakeTimers(new Date('2013-01-03').getTime())
    indexDate = @taskModel.getDateIndex(@sprint)
    assert.equal indexDate, '2013-01-03'

describe 'TaskViewModel.openSelectorPopup', ->

  before ->

    class StubViewModel extends TaskViewModel

      constructor: ->

        @view = {set: ->}
    @viewModel = new StubViewModel
    @model = new Model
    @model.story = {sprint_id: 'abc'}
    @viewModel.model = @model 
    sinon.stub @viewModel.view, 'set'
    sinon.stub @model, 'getStories', (sprintId, successCb) -> successCb 'stub'

  after ->

    @model.getStories.restore()
    @viewModel.view.set.restore()

  it 'should call TaskModel.getStories when the popup is a story-selector', ->

    @viewModel.openSelectorPopup {}, 'story-selector'
    assert @model.getStories.calledWith('abc'), 'getStories not called'

  it 'should set view stories with the returned stories on a successful reload', ->

    assert @viewModel.view.set.calledWith('stories', 'stub'), 'view set not called with the correct arguments'

describe 'TaskViewModel.selectPopupItem', ->

  before ->

    class StubViewModel extends TaskViewModel

      constructor: ->

        @view = {set: (->), get: -> 'red'}
    @viewModel = new StubViewModel
    @taskModel = new TaskModel {summary: 'xyz'}
    @viewModel.model = @taskModel
    sinon.stub @viewModel.view, 'set'
  after ->

    @taskModel.update.restore()
    @taskModel.getStory.restore()
    @viewModel.view.set.restore()

  it 'should call TaskModel.update when the popup is a color selector', ->

    sinon.stub @taskModel, 'update', (key, successCb) -> successCb {rev: 1, value: 'blue'}
    @viewModel.selectPopupItem {}, {selector_id: 'color-selector', value: 'blue'}
    assert @taskModel.update.calledWith('color'), 'requestUpdate not called with the correct arguments'

  it 'should set the view rev and value after a successful request', ->

    assert @viewModel.view.set.calledTwice, 'view is not called twice'    

  it 'should call TaskModel.update and TaskModel.getStory when the popup is a story selector', ->

    @viewModel.view.set.reset()
    @taskModel.update.restore()
    sinon.stub @taskModel, 'update', (key, successCb) -> successCb {rev: 1, value: 'abc'}
    sinon.stub @taskModel, 'getStory', (value, successCb) -> successCb 'stub' 
    @viewModel.selectPopupItem {}, {selector_id: 'story-selector', value: 'abc'}
    assert @taskModel.update.calledWith('story_id'), 'update not called with the correct arguments'
    assert @taskModel.getStory.calledWith('abc'), 'getStory not called with the correct arguments'

  it 'should set the view rev, value and story after successful requests', ->

    assert @viewModel.view.set.calledThrice, 'view is not called three times'
