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

    range = start: '2010-01-05', end: '2010-01-10'

    ret = @view.buildRemainingTime remainingTime, range
    assert.equal ret, 10
  it 'should return the number of the last date within in the sprint', ->

    remainingTime =

      initial: 10
      '2010-01-02': 8 
      '2010-01-04': 7
      '2010-01-08': 6
      '2010-01-09': 5

    range = start: '2010-01-05', end: '2010-01-10'

    ret = @view.buildRemainingTime remainingTime, range
    assert.equal ret, 5
describe 'StoryModel.buildSprintRange', ->

  before ->

    @model = new StoryModel
  it 'should return a calculated sprint range object', ->

    range = @model.buildSprintRange {start: '2010-01-01T00:00:00.000Z', length: 7}
    assert.equal range.start, '2010-01-01'
    assert.equal range.end, '2010-01-08'

describe 'StoryModel.buildRemainingTimeChartData', ->

  before ->

    @model = new StoryModel
    @story = {estimation: 1}
    @range = start: '2010-01-01', end: '2010-01-08'

  it 'should return the story\'s estimation, if there are no remaining_time values specified', ->

    tasks = [

      { remaining_time: {initial: 1} }
    ] 
    chartData = @model.buildRemainingTimeChartData @story, tasks, @range
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}]    
  it 'should return the story\'s estimation, if none of the remaining_time values specified are within the sprint range', ->

    tasks = [

      { remaining_time: {initial: 1, '2010-01-08': 1, '2010-01-09': 1.5, '2010-01-09': 0.5} }
    ] 
    chartData = @model.buildRemainingTimeChartData @story, tasks, @range
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}] 
  it 'should return add up remaining_time values from several tasks', ->

    tasks = [

      { remaining_time: {initial: 1, '2010-01-01': 2, '2010-01-02': 1.5, '2010-01-04': 0.5} }
      { remaining_time: {initial: 1, '2010-01-01': 1, '2010-01-02': 0.5, '2010-01-03': 0.25} }
    ]
    chartData = @model.buildRemainingTimeChartData @story, tasks, @range
    assert.deepEqual chartData, [
      {x: moment('2010-01-01').unix(), y: 3}, 
      {x: moment('2010-01-02').unix(), y: 2},
      {x: moment('2010-01-03').unix(), y: 1.75},
      {x: moment('2010-01-04').unix(), y: 0.75},
    ]
  it 'should exclude remaining_time values, which are not within sprint range', ->

    tasks = [

      { remaining_time: {initial: 1, '2010-01-02': 0.75, '2010-01-08': 0.25} }
    ]
    chartData = @model.buildRemainingTimeChartData @story, tasks, @range
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}, {x: moment('2010-01-02').unix(), y: 0.75}]
  it 'should sort remaining_time values', ->

    tasks = [

      { remaining_time: {initial: 1, '2010-01-02': 0.5, '2010-01-01': 0.75} }
    ]
    chartData = @model.buildRemainingTimeChartData @story, tasks, @range
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 0.75}, {x: moment('2010-01-02').unix(), y: 0.5}]

###describe 'StoryModel.buildChartData', ->

  before ->

    @model = new StoryModel
  it 'should return an empty list, if there are no time_spent values specified', ->

    tasks = [

      { time_spent: {initial: 0} }
    ]
    chartData = @model.buildChartData tasks, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, []
  it 'should return an empty list, if no time_spent value is within sprint range', ->

    tasks = [

      { time_spent: {initial: 0, '2010-01-08': 1, '2010-01-09': 1.5, '2010-01-09': 0.5} }
    ]
    chartData = @model.buildChartData tasks, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, []
  it 'should return cumulative time_spent values', ->

    tasks = [

      { time_spent: {initial: 0, '2010-01-01': 1, '2010-01-07': 1.5} }
    ]
    chartData = @model.buildChartData tasks, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}, {x: moment('2010-01-07').unix(), y: 2.5}]
  it 'should exlude values which are not in sprint range', ->

    tasks = [

      { time_spent: {initial: 0, '2010-01-01': 1, '2010-01-07': 1.5, '2010-01-08': 0.5} }
    ]
    chartData = @model.buildChartData tasks, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}, {x: moment('2010-01-07').unix(), y: 2.5}]
  it 'should add up time spent values from different tasks', ->

    tasks = [

      { time_spent: {initial: 0, '2010-01-01': 1, '2010-01-07': 1.5} }
      { time_spent: {initial: 0, '2010-01-02': 1.5, '2010-01-07': 0.25} }
    ]
    chartData = @model.buildChartData tasks, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{x: moment('2010-01-01').unix(), y: 1}, {x: moment('2010-01-02').unix(), y: 2.5}, {x: moment('2010-01-07').unix(), y: 4.25}]###
