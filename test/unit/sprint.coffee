describe 'SprintViewModel._selectDate', ->

  before ->

    class StubViewModel extends SprintViewModel

      constructor: ->

        @view = {set: (->), get: ->}
    @viewModel = new StubViewModel
    @model = new Model
    @viewModel.model = @model 
    sinon.stub @viewModel.view, 'set'
    $('body').append '<div class="fake_picker date-selector" id="start_date"><div id="fake_start"></div></div>'
    $('body').append '<div class="fake_picker date-selector" id="length"><div id="fake_length"></div></div>'

  after ->

    @viewModel.view.set.restore()
    @viewModel.view.get.restore()
    @viewModel.model.update.restore()
    sinon.stub $.fn.datepicker.restore()
    $('.fake_picker').remove()

  it 'should call model.update when the function is triggered by the start date picker', ->

    sinon.stub @model, 'update', (key, successCb, errorCb) -> successCb {rev: 2, value: '2010-01-01T00:00:00.000Z'}
    sinon.stub @viewModel.view, 'get', -> '2009-01-01T00:00:00.000Z'
    sinon.stub $.fn, 'datepicker'
    @viewModel._selectDate('2010-01-01', {input: '#fake_start'})
    assert @model.update.calledWith('start'), 'model.update not called with the correct arguments.'
  it 'should update the revision', ->

    assert @viewModel.view.set.calledWith('sprint._rev', 2), 'revision not set correctly'
  it 'should set the minimum date on the length datepicker to the chosen start date', ->

    assert $.fn.datepicker.calledWith('option', 'minDate', new Date('2010-01-01T00:00:00.000Z')), 'datepicker("option") not called with the correct arguments.'
  it 'should reset the sprint\'s start on a failed model.update call', ->

    @model.update.restore()
    sinon.stub @model, 'update', (key, successCb, errorCb) -> errorCb 'stub'
    @viewModel.view.set.reset()
    @viewModel._selectDate('2010-01-01', {input: '#fake_start'})
    assert @viewModel.view.set.calledWith('sprint.start', '2009-01-01T00:00:00.000Z'), 'undoValue not set on failed update'
  it 'should set the diff to the start date in days as the sprint\'s length attribute when the function is triggered by the length date picker.', ->

    @model.update.restore()
    sinon.stub @model, 'update', (key, successCb, errorCb) -> successCb {rev: 3, value: '2010-01-10T00:00:00.000Z'}  
    @viewModel.view.get.restore()
    sinon.stub @viewModel.view, 'get', (keypath) -> 

      if keypath == 'sprint.length' then '2010-01-05T00:00:00.000Z'
      else '2010-01-01T00:00:00.000Z'
    @viewModel.view.set.reset()
    @viewModel._selectDate('2010-01-10', {input: '#fake_length'})
    assert @viewModel.view.set.calledWith('sprint.length', 9), 'length not set correctly'
  it 'it should update the revision', ->

    assert @viewModel.view.set.calledWith('sprint._rev', 3), 'revision not set correctly'
  it 'should reset the sprint\'s length on a failed model.update call', ->

    @model.update.restore()
    sinon.stub @model, 'update', (key, successCb, errorCb) -> errorCb 'stub'
    @viewModel.view.get.restore()
    sinon.stub @viewModel.view, 'get', -> 4
    @viewModel.view.set.reset()
    @viewModel._selectDate('2010-01-10', {input: '#fake_length'})
    assert @viewModel.view.set.calledWith('sprint.length', 4), 'undoValue not set on failed update'