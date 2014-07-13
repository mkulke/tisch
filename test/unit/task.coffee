expect = chai.expect

describe 'TaskModel#getDateIndex', ->
  beforeEach ->
    taskModel = new TaskModel
    sprint = {start: '2013-01-01', length: 7}
    @subject = ->
      taskModel.getDateIndex sprint.start, sprint.length

  afterEach ->
    @clock.restore()

  context 'when the current date is after the sprint', ->
    before ->
      @clock = sinon.useFakeTimers(new Date('2013-01-08').getTime())

    it 'returns the last date index of the sprint', ->
      expect(do @subject).to.eq '2013-01-07'

  context 'when the current date is before the sprint', ->
    before ->
      @clock = sinon.useFakeTimers(new Date('2012-12-31').getTime())

    it 'returns the first date index of the sprint', ->
      expect(do @subject).to.eq '2013-01-01'

  context 'when the current date is before the sprint', ->
    before ->
      @clock = sinon.useFakeTimers(new Date('2013-01-03').getTime())

    it 'returns the current date', ->
      expect(do @subject).to.eq '2013-01-03'

describe 'TaskModel#getClosestValueByDateIndex', ->
  beforeEach ->
    taskModel = new TaskModel
    @subject = =>
      taskModel.getClosestValueByDateIndex @indexedTimes, @start, @end
     @indexedTimes =
        '2014-01-02': 2
        '2014-01-04': 3
      @start = '2014-01-01'

  context 'when end is after the most recent time entry', ->
    before ->
      @end = '2014-01-05'

    it 'returns the last time entry', ->
      expect(do @subject).to.eq 3

  context 'when end is before the most recent time entry', ->
    context 'and there is a matching entry', ->
      before ->
        @end = '2014-01-02'

      it 'returns the matching entry', ->
        expect(do @subject).to.eq 2
    context 'and there is no matching entry', ->
      before ->
        @end = '2014-01-03'

      it 'returns the closest entry before end', ->
        expect(do @subject).to.eq 2

  context 'when end is before the first entry', ->
    before ->
      @end = '2013-01-01'

    it 'returns 1', ->
      expect(do @subject).to.eq 1