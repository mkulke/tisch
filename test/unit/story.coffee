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

        @view = {set: ->}
    @viewModel = new StubViewModel
    @storyModel = new StoryModel [], {title: 'xyz'}
    @viewModel.model = @storyModel
    sinon.stub @viewModel.view, 'set'
  after ->

    @storyModel.requestUpdate.restore()
    @storyModel.getSprint.restore()
    @viewModel.view.set.restore()

  it 'should call StoryModel.requestUpdate when the popup is a color selector', ->

    sinon.stub @storyModel, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'blue'}
    @viewModel.selectPopupItem {}, {selector_id: 'color-selector', value: 'blue'}
    assert @storyModel.requestUpdate.calledWith('color', 'blue'), 'requestUpdate not called with the correct arguments'

  it 'should set the view rev and value after a successful request', ->

    assert @viewModel.view.set.calledTwice, 'view is not called twice'    

  it 'should call TaskModel.requestUpdate and TaskModel.getStory when the popup is a story selector', ->

    @viewModel.view.set.reset()
    @storyModel.requestUpdate.restore()
    sinon.stub @storyModel, 'requestUpdate', (key, value, successCb) -> successCb {rev: 1, value: 'abc'}
    sinon.stub @storyModel, 'getSprint', (value, successCb) -> successCb 'stub' 
    @viewModel.selectPopupItem {}, {selector_id: 'sprint-selector', value: 'abc'}
    assert @storyModel.requestUpdate.calledWith 'sprint_id', 'abc'
    assert @storyModel.getSprint.calledWith('abc'), 'getSprint not called with the correct arguments'

  it 'should set the view rev, value and story after successful requests', ->

    assert @viewModel.view.set.calledThrice, 'view is not called three times'

describe 'StoryViewModel.triggerUpdate', ->

  before ->

    @ractiveEvent = {

      node: {localName: 'input', id: 'summary-0'}
      original: {which: 13, preventDefault: ->}
    }

    class StubViewModel extends StoryViewModel

      constructor: ->
    @viewModel = new StubViewModel
    @model = new Model
    @model.type = 'sometype'
    @model.children = {type: 'childtype', objects: [{ summary: 'xyz'}]}
    @viewModel.model = @model
    @viewModel.view = {set: ->}
    sinon.stub @model, 'requestChildUpdate'
  after -> 

    @model.requestChildUpdate.restore()
  it 'should call Model.requestChildUpdate when called the node id is has a child index', ->
  
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @model.requestChildUpdate.calledWith('0', 'summary', 'xyz'), 'requestChildUpdate not called with the correct arguments'
