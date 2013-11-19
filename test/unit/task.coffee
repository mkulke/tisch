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