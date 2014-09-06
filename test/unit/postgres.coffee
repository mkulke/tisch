pg = require('pg')
Q = require('q')
_ = require('underscore')._
chai = require('chai')
chaiAsPromised = require('chai-as-promised')
exec = require('child_process').exec
postgres = require('../../postgres.js')
u = require('../../utils.js')

assert = chai.assert
expect = chai.expect
chai.use chaiAsPromised

query = (queryString, cb) ->

  connectionString = 'postgres://localhost/test'
  pg.connect connectionString, (err, client, done) ->

    client.query queryString, (err, result) ->

      do done
      cb err, result

issueQuery = (queryString, next) ->

  query queryString, (err) ->

    next err if err
    do next unless err

prepareSprints = (next) ->

  queryString = """

    INSERT INTO
    sprints
    (_id, _rev, title, description, color, start, length)
    VALUES
    (1, 3, 'Sprint A', 'bla', 'red', '2013-01-01', 14),
    (2, 6, 'Sprint B', 'blub', 'orange', '2013-01-15', 14),
    (3, 1, 'Sprint C', 'test', 'green', '2014-01-15', 7)
  """

  issueQuery queryString, next

prepareStories = (next) ->

  queryString = """

    INSERT INTO
    stories
    (_id, _rev, title, color, estimation, priority, sprint_id)
    VALUES
    (1, 3, 'Story A', 'yellow', 5, 3, 1),
    (2, 6, 'Story B', 'blue', 4, 4, 2),
    (3, 1, 'Story C', 'green', 5, 5, 1)
  """

  prepareSprints u.partial(issueQuery, queryString, next)

prepareTasks = (next) ->
  queryString = """
    INSERT INTO
    tasks
    (_rev, summary, color, priority, story_id)
    VALUES
    (3, 'Task A', 'red', 3, 1),
    (6, 'Task B', 'orange', 4, 2),
    (1, 'Task C', 'purple', 5, 1),
    (1, 'Task D', 'green', 6, 1)
  """

  prepareStories u.partial(issueQuery, queryString, next)

prepareTimesSpent = (next) ->

  queryString = """

    INSERT INTO
    times_spent
    (_id, date, days, task_id)
    VALUES
    (1, '2014-01-01', 2, 1),
    (2, '2014-01-02', 3, 1),
    (3, '2014-01-03', 1, 2),
    (4, '2014-01-15', 1, 1)
  """

  prepareTasks u.partial(issueQuery, queryString, next)

prepareRemainingTimes = (next) ->

  queryString = """

    INSERT INTO
    remaining_times
    (_id, date, days, task_id)
    VALUES
    (1, '2013-01-01', 2, 1),
    (2, '2013-01-02', 3, 1),
    (3, '2013-01-03', 10, 3),
    (4, '2013-01-15', 1, 1)
  """

  prepareTasks u.partial(issueQuery, queryString, next)

resetTaskSequence = (next) ->
  issueQuery "ALTER SEQUENCE tasks__id_seq RESTART WITH 1", next

cleanupSprints = (next) ->
  queryString = 'DELETE FROM sprints'
  resetTaskSequence u.partial(issueQuery, queryString, next)

prepare = (next) ->

  exec 'createdb test', (err) ->

    console.log("exec error: #{err}") if err
    exec 'psql -d test -f test/test.sql', (err) ->

      console.log("exec error: #{err}") if err
      next err

cleanup = (next) ->

  postgres.cleanup().then ->

    exec 'dropdb test', (err) ->

      console.log("exec error: #{err}") if err
      next err

describe 'postgres', ->

  expectItToReturnRows = (options) ->

    it "returns #{options.n} objects", ->

      expect(do @subject).to.eventually.be.an('Array').and.have.length(options.n)
  expectItToBeSortable = (options) ->

    context 'when a sort parameter is specified', ->

      context 'which is invalid', ->

        before ->

          @args = [null, {wrong: 1}]

        it 'throws an error', ->

          expect(do @subject).to.be.rejectedWith(Error)

      context 'which is ascending', ->

        before ->

          object = {}
          object[options.column] = 1
          @args = [null, object]

        it "returns sorted #{options.table} in ascending order", ->

          expect(do @subject).to.eventually.satisfy (rows) ->

            _.pluck(rows, options.column)[0] == _.first(options.orderedValues)
      context 'which is descending', ->
        before ->
          object = {}
          object[options.column] = 0
          @args = [null, object]

        it "returns sorted #{options.table} in descending order", ->
          expect(do @subject).to.eventually.satisfy (rows) ->
            _.pluck(rows, options.column)[0] == _.last(options.orderedValues)

  expectItToReturnOneRow = ->
    it 'returns a single row', ->
      expect(do @subject).to.eventually.satisfy (object) =>
        object._id == @id

    context 'with an invalid id', ->
      before ->
        @id = 'wrong'

      it 'throws an error', ->
        expect(do @subject).to.be.rejectedWith(Error)

  before prepare
  after cleanup

  describe 'sprint functions', ->

    beforeEach prepareSprints
    afterEach cleanupSprints

    describe 'findSprints', ->

      before ->

        @args = []
        @subject = ->

          postgres.findSprints @args...

      expectItToReturnRows n: 3

      expectItToBeSortable table: 'sprints', column: 'color', orderedValues: ['green', 'orange', 'red']

      context 'when a filtering parameter is specified', ->

        before ->

          @args = [{color: 'orange'}]
        it 'returns only filtered sprints', ->

          expect(do @subject).to.eventually.have.length(1).and.satisfy (rows) ->

            _.first(rows).color == 'orange'
        context 'and another one is added', ->

          before ->

            @args = [{length: 14, "_rev": 3}]
          it 'returns sprints filtered by both clauses', ->

            expect(do @subject).to.eventually.have.length(1)
        context 'which is invalid', ->

          before ->

            @args = [{invalid: false}]
          it 'throws an error', ->

            expect(do @subject).to.eventually.be.rejectedWith(Error);
      context 'when a combination of both filter and sort parameters is specified', ->

        before ->

          @args = [{length: 14}, {'color': 1}]
        it 'returns filtered sorted sprints', ->

          expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

            _.pluck(rows, 'color')[0] == 'orange'
    describe 'updateSprint', ->

      before ->

        @id = 3
        @rev = 1
        @column = 'color'
        @value = 'red'
        @subject = ->

          postgres.updateSprint @id, @rev, @column, @value
      context 'when all parameters are supplied', ->

        before ->

          @args = [@id, @rev, @column, @value]
        it 'returns the modifed sprint', ->

          expect(do @subject).to.eventually.satisfy (sprint) =>

            sprint[@column] == @value
        it 'modifies the sprint in the db', ->

          expect(@subject().then(=> Q.nfcall(query, "SELECT * FROM sprints WHERE _id=#{@id}"))).to.eventually.satisfy (result) =>

            result.rows[0][@column] == @value
      context 'when an illegal column is specified', ->

        before ->

          @column = 'wrong'
        it 'throws an error', ->

          expect(do @subject).to.be.rejectedWith(Error)
      context 'when the wrong revision is specified', ->

        before ->

          @rev = @rev + 1
        it 'throws an error', ->

          expect(do @subject).be.rejectedWith(Error)
      context 'when a non-existent id is specified', ->

        before ->

          @id = 'wrong'
        it 'throws an error', ->

          expect(do @subject).to.be.rejectedWith(Error)
    describe 'findSingleSprint', ->

      before ->

        @id = '3'
        @subject = ->

          postgres.findSingleSprint @id

      do expectItToReturnOneRow
  describe 'story functions', ->

    beforeEach prepareStories
    afterEach cleanupSprints

    describe 'findStories', ->

      before ->

        @args = []
        @subject = ->

          postgres.findStories @args...

      expectItToReturnRows n: 3

      expectItToBeSortable table: 'stories', column: 'color', orderedValues: ['blue', 'green', 'yellow']
      context 'when both sorting and filtering options are specified', ->

        before ->

          @args = [{estimation: 5}, {'color': 1}]
        it 'returns filtered sorted stories', ->

          expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

            _.pluck(rows, 'color')[0] == 'green'

    describe 'findSingleStory', ->
      before ->
        @id = '3'
        @subject = ->
          postgres.findSingleSprint @id

      do expectItToReturnOneRow
  describe 'task functions', ->
    beforeEach prepareTasks
    afterEach cleanupSprints

    describe 'addTask', ->
      before ->
        @initialData =
          description: 'test'
          color: 'green'
          summary: 'test'
          story_id: 3

        @subject = ->
          postgres.addTask @initialData

      it 'is succesful', ->
        expect(do @subject).to.eventually.be.fulfilled

      it 'returns an object with an empty remaining time property', ->
        expect(do @subject).to.eventually.have.property('remaining_time').to.deep.equal {}

      it 'returns an object with an empty time spent property', ->
        expect(do @subject).to.eventually.have.property('time_spent').to.deep.equal {}

      it 'returns an object with correct _id and _rev propertie', ->
        expect(do @subject).to.eventually.satisfy (result) ->
          expect(result).to.have.property '_id'
          expect(result).to.have.property '_rev', 1

      it 'adds a row to the tasks table', (done) ->
        @subject().then ->
          query 'SELECT count(*) FROM tasks', (err, result) ->
            expect(result.rows[0]).to.have.property('count', '5')
            do done

      context 'and there is an illegal column in the initial data', ->
        before ->
          _.extend @initialData, illegal: 'yes'

        it 'throws an error', ->
          expect(do @subject).to.eventually.be.rejectedWith(Error)
    describe 'removeTask', ->
      before ->
        @id = 1

        @subject = ->
          postgres.removeTask @id

      it 'is succesful', ->
        expect(do @subject).to.eventually.be.fulfilled

      it 'removes a row from the tasks table', (done) ->
        @subject().then ->
          query 'SELECT count(*) FROM tasks', (err, result) ->
            expect(result.rows[0]).to.have.property('count', '3')
            do done
      context 'when there are remaining_times associated', ->
        beforeEach prepareRemainingTimes

        it "removes them", (done) ->
          @subject().then ->
            query 'SELECT count(*) FROM remaining_times', (err, result) ->
              expect(result.rows[0]).to.have.property('count', '1')
              do done
      context 'when there are times_spent associated', ->
        beforeEach prepareTimesSpent

        it "removes them", (done) ->
          @subject().then ->
            query 'SELECT count(*) FROM times_spent', (err, result) ->
              expect(result.rows[0]).to.have.property('count', '1')
              do done

      it 'returns the removed task', ->
        expect(do @subject).to.eventually.have.property '_id', '1'

    describe 'findTasks', ->
      before ->
        @args = []
        @subject = ->
          postgres.findTasks @args...

      expectItToReturnRows n: 4

      expectItToBeSortable table: 'tasks', column: 'priority', orderedValues: [3, 4, 5, 6]

      context 'when tasks have remaining time values', ->
        beforeEach prepareRemainingTimes

        before ->
          @args = [{'_id': 3}]

        expectItToReturnRows n: 1

        it 'returns objects with remaining time objects', ->
          expect(do @subject).to.eventually.satisfy (rows) ->
            expect(rows[0]).to.have.property('remaining_time').to.deep.equal('2013-01-03': 10)

      context 'when tasks have time spent values', ->
        beforeEach prepareTimesSpent

        before ->
          @args = [{'_id': 2}]

        expectItToReturnRows n: 1

        it 'returns objects with time spent objects', ->
          expect(do @subject).to.eventually.satisfy (rows) ->
            expect(rows[0]).to.have.property('time_spent').to.deep.equal('2014-01-03': 1)

    describe 'findSingleTask', ->
      before ->
        @id = 1
        @subject = ->

          postgres.findSingleTask @id

      do expectItToReturnOneRow

      context 'when the task has remaining time values', ->
        before ->
          @id = '1'

        beforeEach prepareRemainingTimes

        it 'returns an object which contains a remaining_time object', ->
          expect(do @subject).to.eventually.have.property('remaining_time').to.deep.equal
            '2013-01-01': 2
            '2013-01-02': 3
            '2013-01-15': 1

      context 'when the task has spent time values', ->
        before ->
          @id = '1'

        beforeEach prepareTimesSpent

        it 'returns an object which contains a time_spent object', ->
          expect(do @subject).to.eventually.have.property('time_spent').to.deep.equal
            '2014-01-01': 2
            '2014-01-02': 3
            '2014-01-15': 1

    describe 'updateTask',  ->
      context 'when updating color', ->
        before ->
          @subject = ->
            postgres.updateTask 4, 1, 'color', 'blue'

        it 'returns the modifed task', ->
          expect(do @subject).to.eventually.satisfy (task) ->
            task['color'] == 'blue'

        it 'returns a task with a remaining_time property', ->
          expect(do @subject).to.eventually.have.property 'remaining_time'

      context 'when updating time_spent', ->
        before ->
          @subject = ->
            postgres.updateTask 3, 1, 'time_spent', 1.5, '2010-01-01'

        it 'returns the modified (enriched) task', ->
          expect(do @subject).to.eventually.satisfy (task) ->
            _.isEqual task.time_spent,
              '2010-01-01': 1.5

      context 'when updating remaining_times', ->
        beforeEach prepareRemainingTimes

        before ->
          @subject = ->
            postgres.updateTask 3, 2, 'remaining_time', 1, '2010-01-01'

        it 'returns the modified (enriched) task', ->
          expect(do @subject).to.eventually.satisfy (task) ->
            _.isEqual task.remaining_time,
              '2010-01-01': 1,
              '2013-01-03': 10

        context 'and the task already has an entry for the specified date', ->

          before ->

            @subject = ->

              postgres.updateTask 3, 2, 'remaining_time', 5, '2013-01-03'
          it 'updates the row in the remaining times table', (done) ->

            @subject().then ->

              query "SELECT days FROM remaining_times WHERE task_id = 3 AND date = '2013-01-03'", (err, result) ->

                expect(result.rows[0]).to.have.property('days', 5)
                do done
          it 'increases the rev for the respective task', (done) ->
            @subject().then ->
              query 'SELECT _rev FROM tasks WHERE _id = 3', (err, result) ->
                expect(result.rows[0]).to.have.property('_rev', 3)
                do done
          it 'does not add a row to the remaining times table', (done) ->

            @subject().then ->

              query 'SELECT count(*) FROM remaining_times', (err, result) ->

                expect(result.rows[0]).to.have.property('count', '4')
                do done

        context 'and the specified date does not exist for the task yet', ->

          before ->

            @subject = ->

              postgres.updateTask 4, 1, 'remaining_time', 5, '2014-01-05'
          it 'adds a row to the remaining times table', (done) ->

            @subject().then ->

              query 'SELECT count(*) FROM remaining_times', (err, result) ->

                expect(result.rows[0]).to.have.property('count', '5')
                do done
          it 'increases the rev for the respective task', (done) ->

            @subject().then ->

              query 'SELECT _rev FROM tasks WHERE _id = 4', (err, result) ->

                expect(result.rows[0]).to.have.property('_rev', 2)
                do done
        context 'and the task does not exist', ->
          before ->
            @subject = ->
              postgres.updateTask 10, 1, 'remaining_time', 5, '2014-01-05'

          it 'throws an exception', ->
            expect(do @subject).to.eventually.be.rejectedWith(Error)

        context "and the specified task's rev is wrong", ->
          before ->
            @subject = ->
              postgres.updateTask 4, 2, 'remaining_time', 5, '2014-01-05'

          it 'throws an exception', ->
            expect(do @subject).to.eventually.be.rejectedWith(Error)

  describe 'calculation functions', ->

    describe 'remaining times', ->

      beforeEach prepareRemainingTimes
      afterEach cleanupSprints

      describe 'getStoriesRemainingTime', ->

        before ->

          @args = [['1', '3'], {start: '2013-01-01', end: '2013-01-14'}]
          @subject = ->

            postgres.getStoriesRemainingTime @args...
        it 'returns correct calculations', ->

          expect(do @subject).to.eventually.deep.equal([
            ['1', [
              ['2013-01-01', 4],
              ['2013-01-02', 5],
              ['2013-01-03', 14],
            ]],
            ['3', [
              ['2013-01-01', 5]
            ]]
          ])
        context 'when faulty ids are specified', ->

          before ->

            @args[0] = ['wrong']
          it 'throws an error', ->

            expect(do @subject).to.be.rejectedWith(Error)
        context 'when no ids are specified', ->

          before ->

            @args[0] = null
          it 'returns the calculations for all stories', ->

            expect(do @subject).to.eventually.deep.equal([
              ["1", [
                ["2013-01-01", 4],
                ["2013-01-02", 5],
                ["2013-01-03", 14]
              ]],
              ["2", [
                ["2013-01-01",1]
              ]],
              ["3", [
                ["2013-01-01",5]
              ]]
            ])
        context 'when empty stories are specified', ->

          before ->

            @args[0] = ['3']
          it 'returns the estimation for those stories', ->

            expect(do @subject).to.eventually.deep.equal([['3', [['2013-01-01', 5]]]])
    describe 'task count', ->

      beforeEach prepareTasks
      afterEach cleanupSprints

      describe 'getStoriesTaskCount', ->

        before ->

          @args = [['1', '2']]
          @subject = ->

            postgres.getStoriesTaskCount @args...
        it 'returns the number of tasks in the specified stories', ->

          expect(do @subject).to.eventually.deep.equal([['1', 3], ['2', 1]])
        context 'when faulty ids are specified', ->

          before ->

            @args = [['wrong', 'false']]
          it 'throws an error', ->

            expect(do @subject).to.be.rejectedWith(Error)
        context 'when no ids are specified', ->

          before ->

            @args = []
          it 'returns calculations for all stories', ->

            expect(do @subject).to.eventually.deep.equal([['1', 3], ['2', 1], ['3', 0]])
        context 'when empty stories are specified', ->

          before ->

            @args[0] = ['3']
          it 'returns 0 for that story', ->

            expect(do @subject).to.eventually.deep.equal([['3', 0]])
    describe 'times spent', ->

      beforeEach prepareTimesSpent
      afterEach cleanupSprints

      describe 'getStoriesTimeSpent', ->

        before ->

          @args = [['1', '2'], {start: '2014-01-01', end: '2014-01-14'}]
          @subject = ->

            postgres.getStoriesTimeSpent @args...
        it 'returns correct calculations', ->

          expect(do @subject).to.eventually.deep.equal([
            ['1', [
              ['2014-01-01', 2],
              ['2014-01-02', 3],
            ]],
            ['2', [
              ['2014-01-03', 1],
            ]]
          ])
        context 'when no ids are specified', ->

          before ->

            @args[0] = null

          it 'returns calculations for all stories', ->

            expect(do @subject).to.eventually.deep.equal([
              ['1', [
                ['2014-01-01', 2],
                ['2014-01-02', 3],
              ]],
              ['2', [
                ['2014-01-03', 1],
              ]],
              ['3', [
              ]]
            ])
        context 'when faulty ids are specified', ->

          before ->

            @args = [['wrong', 'false'], {start: '2014-01-01', end: '2014-01-14'}]
          it 'throws an error', ->

            expect(do @subject).to.be.rejectedWith(Error)
        context 'when empty stories are specified', ->

          before ->

            @args[0] = ['3']
          it 'returns 0 for that story', ->

            expect(do @subject).to.eventually.deep.equal([['3', []]])