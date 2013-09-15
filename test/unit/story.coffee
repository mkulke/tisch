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
    @viewModel.view = {set: (->), get: -> 'abc'}
    sinon.stub @model, 'updateChild'
  after -> 

    @model.updateChild.restore()
  it 'should call Model.updateChild when called the node id is has a child index', ->
  
    @viewModel.triggerUpdate(@ractiveEvent)
    assert @model.updateChild.calledWith('0', 'summary'), 'updateChild not called with the correct arguments'

describe 'StoryViewModel._calculatePriority', ->

  before ->

    class StubViewModel extends StoryViewModel

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

describe 'StoryViewModel._handleSortstop', ->

  before ->

    class StubViewModel extends StoryViewModel

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
    assert.equal @model.children.objects[1].priority, 2

