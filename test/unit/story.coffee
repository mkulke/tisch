describe 'StoryViewModel.openSelectorPopup', ->

  before ->

    class StubViewModel extends StoryViewModel

      constructor: ->

        @view = {set: ->}
    @viewModel = new StubViewModel
    @model = new Model
    @viewModel.model = @model 
    sinon.stub @viewModel.view, 'set'
    sinon.stub @model, 'getSprints', (successCb) -> successCb 'stub'

  after ->

    @model.getSprints.restore()
    @viewModel.view.set.restore()

  it 'should call StoryModel.getSprints when the popup is a sprint-selector', ->

    @viewModel.openSelectorPopup {}, 'sprint-selector'
    assert @model.getSprints.called, 'getSprints not called'

  it 'should set view sprints with the returned sprints on a successful reload', ->

    assert @viewModel.view.set.calledWith('sprints', 'stub'), 'view set not called with the correct arguments'

describe 'StoryViewModel.selectPopupItem', ->

  before ->

    class StubViewModel extends StoryViewModel

      constructor: ->

        @view = {set: (->), get: -> 'abc'}
    @viewModel = new StubViewModel
    @storyModel = new StoryModel [], {title: 'xyz'}
    @viewModel.model = @storyModel
    sinon.stub @viewModel.view, 'set'
  after ->

    @storyModel.update.restore()
    @storyModel.getSprint.restore()
    @viewModel.view.set.restore()

  it 'should call StoryModel.update when the popup is a color selector', ->

    sinon.stub @storyModel, 'update', (key, successCb) -> successCb {rev: 1, value: 'blue'}
    @viewModel.selectPopupItem {}, {selector_id: 'color-selector', value: 'blue'}
    assert @storyModel.update.calledWith('color'), 'update not called with the correct arguments'

  it 'should set the view rev and value after a successful request', ->

    assert @viewModel.view.set.calledTwice, 'view is not called twice'    

  it 'should call StoryModel.update and StoryModel.getSprint when the popup is a story selector', ->

    @viewModel.view.set.reset()
    @storyModel.update.restore()
    sinon.stub @storyModel, 'update', (key, successCb) -> successCb {rev: 1, value: 'abc'}
    sinon.stub @storyModel, 'getSprint', (value, successCb) -> successCb 'stub' 
    @viewModel.selectPopupItem {}, {selector_id: 'sprint-selector', value: 'abc'}
    assert @storyModel.update.calledWith('sprint_id'), 'update not called with the correct arguments'
    assert @storyModel.getSprint.calledWith('abc'), 'getSprint not called with the correct arguments'

  it 'should set the view rev, value and story after successful requests', ->

    assert @viewModel.view.set.calledThrice, 'view is not called three times'

describe 'StoryView.buildRemainingTime', ->

  before ->

    class StubView extends StoryView

      constructor: ->

        @model = {children: {}}
    @view = new StubView
  it 'should return the initial remaining time when there are no date/number pairs', ->

    ret = @view.buildRemainingTime {initial: 9.5}, {} 
    assert.equal ret, 9.5
  it 'should return the initial remaining time when none of the date/number pairs is within in the sprint', ->

    remainingTime =

      initial: 10
      '2010-01-02': 8 
      '2010-01-04': 7
      '2010-01-10': 6

    sprint = start: '2010-01-05T00:00:00.000Z', length: 5

    ret = @view.buildRemainingTime remainingTime, sprint
    assert.equal ret, 10
  it 'should return the number of the last date within in the sprint', ->

    remainingTime =

      initial: 10
      '2010-01-02': 8 
      '2010-01-04': 7
      '2010-01-08': 6
      '2010-01-09': 5

    sprint = start: '2010-01-05T00:00:00.000Z', length: 5

    ret = @view.buildRemainingTime remainingTime, sprint
    assert.equal ret, 5