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

prepare = (next) ->

  exec 'createdb test', (err) ->

  	console.log("exec error: #{err}") if err
  	exec 'psql -d test -f test/test.sql', (err) ->

  		console.log("exec error: #{err}") if err
  		next err

cleanup = (next) ->

	postgres.cleanup().then ->

		exec 'dropdb test', (err) ->

			console.log("exec error: #{error}") if err
			next err

describe 'postgres db functions', ->

	expectItToReturnRows = (options) ->

		it "returns #{options.n} objects", ->

			expect(do @subject).to.eventually.be.an('Array').and.have.length(options.n)
	expectItToBeSortable = ->

		context 'when specifying a sort parameter', ->

			context 'which is valid', ->

				context 'and ascending', ->

					beforeEach ->

						@args = [null, {color: 1}]

					it 'returns sorted sprints in ascending order', ->

						expect(do @subject).to.eventually.satisfy (rows) ->

							_.pluck(rows, 'color')[0] == 'orange'	
				context 'and descending', ->

					beforeEach ->

						@args = [null, {color: 0}]

					it 'returns sorted sprints in descending order', ->

						expect(do @subject).to.eventually.satisfy (rows) ->

							_.pluck(rows, 'color')[0] == 'red'
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

	describe 'findSprints', ->

		beforeEach (next) ->

			@args = []
			@subject = ->

				postgres.findSprints @args...
			issueQuery """

				INSERT INTO 
				sprints 
				(_id, _rev, title, description, color, start, length)
				VALUES
				(1, 3, 'Sprint A', 'bla', 'red', '2013-01-01', 14),
				(2, 6, 'Sprint B', 'blub', 'orange', '2013-01-15', 14)
			""", next
		afterEach (next) ->

			issueQuery 'DELETE FROM sprints', next

		expectItToReturnRows n: 2

		do expectItToBeSortable

		context 'when specifying a filter parameter', ->
		
			context 'which is valid', ->

				beforeEach ->

					@args = [{color: 'orange'}]
				it 'returns only filtered sprints', ->

					expect(do @subject).to.eventually.have.length(1).and.satisfy (rows) ->

						_.first(rows).color == 'orange'
			context 'which is invalid', ->

				beforeEach ->

					@args = [{invalid: false}]

				it 'throws an error', ->

					expect(do @subject).to.eventually.be.rejectedWith(Error);
			context 'and adding another one', ->

				beforeEach (next) ->

					@args = [{length: 14, "_rev": 3}]
					issueQuery """

						INSERT INTO
						sprints
						(_id, _rev, title, color, start, length)
						VALUES
						(3, 1, 'Sprint C', 'green', '2014-01-01', 3)
					""", next
				it 'returns sprints filtered by both clauses', ->

					expect(do @subject).to.eventually.have.length(1)
		context 'when specifying a combination of both', ->

			beforeEach (next) ->

				@args = [{length: 14}, {'color': 1}]
				issueQuery """

					INSERT INTO
					sprints
					(_id, _rev, title, color, start, length)
					VALUES
					(3, 1, 'Sprint C', 'green', '2014-01-01', 3)
				""", next
			it 'returns filtered sorted sprints', ->

				expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

					_.pluck(rows, 'color')[0] == 'orange'
	describe 'updateSprint', ->

		beforeEach (next) ->

			@id = 3
			@rev = 1
			@column = 'color'
			@value = 'red'
			@subject = ->

				postgres.updateSprint @id, @rev, @column, @value
			issueQuery """

				INSERT INTO
				sprints
				(_id, _rev, title, color, start, length)
				VALUES
				(3, 1, 'Sprint C', 'green', '2014-01-01', 3)
			""", next
		afterEach (next) ->

			issueQuery 'DELETE FROM sprints', next
		context 'when all parameters are supplied', ->

			it 'returns the modifed sprint', ->

				expect(do @subject).to.eventually.satisfy (sprint) =>

					sprint[@column] == @value
			it 'modifies the sprint in the db', ->

				expect(@subject().then(=> Q.nfcall(query, "SELECT * FROM sprints WHERE _id=#{@id}"))).to.eventually.satisfy (result) =>
					
				 	result.rows[0][@column] == @value
		context 'when specifying an illegal column', ->

			beforeEach ->

				@column = 'wrong'
			it 'throws an error', ->
		
				expect(do @subject).to.be.rejectedWith(Error)
		context 'when specifying the wrong revision', ->
	
			beforeEach ->

				@rev = @rev + 1
			it 'throws an error', ->

				expect(do @subject).be.rejectedWith(Error)
		context 'when specifying a non-existent id', ->

			beforeEach ->

				@id = @id + 1
			it 'throws an error', ->

				expect(do @subject).to.be.rejectedWith(Error)
	describe 'findSingleSprint', ->

		before (next) ->

			@id = '3'
			@subject = ->

				postgres.findSingleSprint @id
			issueQuery """

				INSERT INTO
				sprints
				(_id, _rev, title, color, start, length)
				VALUES
				(#{@id}, 1, 'Sprint D', 'yellow', '2014-01-01', 3)
			""", next	

		after (next) ->

			issueQuery 'DELETE FROM sprints', next

		do expectItToReturnOneRow
	describe 'findStories', ->

		beforeEach (next) ->

			@args = []
			@subject = ->

				postgres.findStories @args...
			issueQuery """

				INSERT INTO 
				stories 
				(_id, _rev, title, color, estimation, priority, sprint_id)
				VALUES
				(1, 3, 'Story A', 'red', 5, 3, 1),
				(2, 6, 'Story B', 'orange', 4, 4, 2)
			""", next
		afterEach (next) ->

			issueQuery 'DELETE FROM stories', next
		expectItToReturnRows {n: 2}

		do expectItToBeSortable

		context 'when sorting a filtering of both', ->

			beforeEach (next) ->

				@args = [{estimation: 5}, {'color': 1}]
				issueQuery """

					INSERT INTO
					stories
					(_id, _rev, title, color, estimation, priority, sprint_id)
					VALUES
					(3, 1, 'Story C', 'green', 5, 5, 1)
				""", next
			it 'returns filtered sorted sprints', ->

				expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

					_.pluck(rows, 'color')[0] == 'green'
	describe 'findSingleStory', ->

		before (next) ->

			@id = '3'
			@subject = ->

				postgres.findSingleStory @id
			issueQuery """

				INSERT INTO
				stories
				(_id, _rev, title, color, estimation, priority, sprint_id)
				VALUES
				(3, 1, 'Story C', 'green', 5, 5, 1)
			""", next	

		after (next) ->

			issueQuery 'DELETE FROM stories', next

		do expectItToReturnOneRow
	describe 'findTasks', ->

		beforeEach (next) ->

			@args = []
			@subject = ->

				postgres.findTasks @args...
			issueQuery """

				INSERT INTO 
				tasks 
				(_id, _rev, summary, color, priority, story_id)
				VALUES
				(1, 3, 'Task A', 'red', 3, 1),
				(2, 6, 'Task B', 'orange', 4, 2)
			""", next
		afterEach (next) ->

			issueQuery 'DELETE FROM tasks', next
		expectItToReturnRows {n: 2}

		do expectItToBeSortable

		context 'when sorting a filtering of both', ->

			beforeEach (next) ->

				@args = [{_rev: 6}, {'color': 1}]
				issueQuery """

					INSERT INTO
					tasks
					(_id, _rev, summary, color, priority, story_id)
					VALUES
					(3, 6, 'Task C', 'green', 5, 1)
				""", next
			it 'returns filtered sorted sprints', ->

				expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

					_.pluck(rows, 'color')[0] == 'green'
	describe 'findSingleTask', ->

		before (next) ->

			@id = '3'
			@subject = ->

				postgres.findSingleTask @id
			issueQuery """

				INSERT INTO
				tasks
				(_id, _rev, summary, color, priority, story_id)
				VALUES
				(3, 1, 'Story C', 'green', 5, 1)
			""", next	

		after (next) ->

			issueQuery 'DELETE FROM tasks', next

		do expectItToReturnOneRow
