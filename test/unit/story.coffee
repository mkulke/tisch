expect = chai.expect

describe 'StoryModel#buildRemainingTime', ->
  before ->
    @model = new StoryModel

  context 'when there are no data/number pairs specified', ->
    before ->
      @subject = ->
        range = start: '2010-01-05', end: '2010-01-10'
        @model.buildRemainingTime {}, range

    it 'returns 1', ->
      expect(do @subject).to.eq(1)
  context 'when none of the date/number pairs is within in the sprint', ->

    before ->

      @subject = ->

        remainingTime =

          '2010-01-02': 8
          '2010-01-04': 7
          '2010-01-11': 6
        range = start: '2010-01-05', end: '2010-01-10'
        @model.buildRemainingTime remainingTime, range

    it 'returns 1', ->

      expect(do @subject).to.eq(1)
  it 'should return the number of the last date within in the sprint', ->

    remainingTime =

      initial: 10
      '2010-01-02': 8
      '2010-01-04': 7
      '2010-01-08': 6
      '2010-01-10': 5

    range = start: '2010-01-05', end: '2010-01-10'

    ret = @model.buildRemainingTime remainingTime, range
    assert.equal ret, 5

describe 'StoryModel.buildTimeSpent', ->

  before ->

    @model = new StoryModel
  it 'should return 0 when there are no date/number pairs', ->

    range = start: '2010-01-05', end: '2010-01-10'
    ret = @model.buildTimeSpent {}, range
    assert.equal ret, 0
  it 'should return 0 when none of the date/number pairs is within in the sprint', ->

    timeSpent =

      initial: 0
      '2010-01-02': 1
      '2010-01-04': 2
      '2010-01-11': 3

    range = start: '2010-01-05', end: '2010-01-10'

    ret = @model.buildTimeSpent timeSpent, range
    assert.equal ret, 0
  it 'should return the cumulative value of all dates within in the sprint', ->

    timeSpent =

      initial: 0
      '2010-01-02': 1
      '2010-01-04': 2
      '2010-01-08': 3
      '2010-01-09': 4

    range = start: '2010-01-05', end: '2010-01-10'

    ret = @model.buildTimeSpent timeSpent, range
    assert.equal ret, 7

describe 'StoryModel.buildRemainingTimeChartData', ->

  before ->

    @model = new StoryModel
    @range = start: '2010-01-01', end: '2010-01-08'

  it 'should return the story\'s estimation, if there are no remaining_time values specified', ->

    remainingTimes = [{}]
    chartData = @model.buildRemainingTimeChartData 1, remainingTimes, @range
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}]
  it 'should return the story\'s estimation, if none of the remaining_time values specified are within the sprint range', ->

    remainingTimes = [{'2010-01-09': 1, '2010-01-10': 1.5, '2010-01-10': 0.5}]
    chartData = @model.buildRemainingTimeChartData 1, remainingTimes, @range
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}]
  it 'should return add up remaining_time values from several tasks', ->

    remainingTimes = [

      {'2010-01-01': 2, '2010-01-02': 1.5, '2010-01-04': 0.5}
      {'2010-01-01': 1, '2010-01-02': 0.5, '2010-01-03': 0.25}
    ]
    chartData = @model.buildRemainingTimeChartData(1, remainingTimes, @range)
    assert.deepEqual chartData, [
      {date: '2010-01-01', value: 3},
      {date: '2010-01-02', value: 2},
      {date: '2010-01-03', value: 1.75},
      {date: '2010-01-04', value: 0.75},
    ]
  it 'should exclude remaining_time values, which are not within sprint range', ->

    remainingTimes = [{'2010-01-02': 0.75, '2010-01-09': 0.25}]
    chartData = @model.buildRemainingTimeChartData 1, remainingTimes, @range
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}, {date: '2010-01-02', value: 0.75}]
  it 'should sort remaining_time values', ->

    remainingTimes = [{'2010-01-02': 0.5, '2010-01-01': 0.75}]
    chartData = @model.buildRemainingTimeChartData 1, remainingTimes, @range
    assert.deepEqual chartData, [{date: '2010-01-01', value: 0.75}, {date: '2010-01-02', value: 0.5}]
  it 'should initialize the first sprint date with 1, if not present in remaining_time values', ->

    remainingTimes = [{'2010-01-02': 1.5, '2010-01-03': 0.5}]
    chartData = @model.buildRemainingTimeChartData 2.5, remainingTimes, @range
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}, {date: '2010-01-02', value: 1.5}, {date: '2010-01-03', value: 0.5}]

describe 'StoryModel.buildTimeSpentChartData', ->

  before ->

    @model = new StoryModel
  it 'should return an empty list, if there are no time_spent values specified', ->

    timesSpent = [{initial: 0}]
    chartData = @model.buildTimeSpentChartData timesSpent, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, []
  it 'should return an empty list, if no time_spent value is within sprint range', ->

    timesSpent = [{initial: 0, '2010-01-09': 1, '2010-01-10': 1.5, '2010-01-10': 0.5}]
    chartData = @model.buildTimeSpentChartData timesSpent, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, []
  it 'should return cumulative time_spent values', ->

    timesSpent = [{initial: 0, '2010-01-01': 1, '2010-01-07': 1.5}]
    chartData = @model.buildTimeSpentChartData timesSpent, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}, {date: '2010-01-07', value: 2.5}]
  it 'should exlude values which are not in sprint range', ->

    timesSpent = [{initial: 0, '2010-01-01': 1, '2010-01-07': 1.5, '2010-01-09': 0.5}]
    chartData = @model.buildTimeSpentChartData timesSpent, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}, {date: '2010-01-07', value: 2.5}]
  it 'should add up time spent values from different tasks', ->

    timesSpent = [

      {initial: 0, '2010-01-01': 1, '2010-01-07': 1.5}
      {initial: 0, '2010-01-02': 1.5, '2010-01-07': 0.25}
    ]
    chartData = @model.buildTimeSpentChartData timesSpent, {start: '2010-01-01', end: '2010-01-08'}
    assert.deepEqual chartData, [{date: '2010-01-01', value: 1}, {date: '2010-01-02', value: 2.5}, {date: '2010-01-07', value: 4.25}]
