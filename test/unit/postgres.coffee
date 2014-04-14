pg = require('pg')
_ = require('underscore')._
chai = require('chai')
chaiAsPromised = require('chai-as-promised')
exec = require('child_process').exec
postgres = require('../../postgres.js')
u = require('../../utils.js')

assert = chai.assert
expect = chai.expect
chai.use chaiAsPromised

runQuery = (queryString, next) ->

	connectionString = 'postgres://localhost/test'
	pg.connect connectionString, (err, client, done) ->

		client.query queryString, (result, err) ->

			do done
			do next

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

	before prepare
	after cleanup

	describe 'findSprints', ->

		beforeEach (next) ->

			@subject = ->

				postgres.findSprints @args...
			runQuery """

				INSERT INTO 
				sprints 
				(_id, _rev, title, description, color, start, length)
				VALUES
				(1, 3, 'Sprint A', 'bla', 'red', '2013-01-01', 14),
				(2, 6, 'Sprint B', 'blub', 'orange', '2013-01-15', 14)
			""", next
		afterEach (next) ->

			runQuery 'DELETE FROM sprints', next
		it 'returns an array', ->

			expect(do @subject).to.eventually.be.an('Array')
		it 'returns two sprints', ->

			expect(do @subject).to.eventually.have.length(2)
		context 'when specifying a filter parameter', ->
		
			context 'which is valid', ->

				before ->

					@args = [{color: 'orange'}]
				it 'return one orange sprint', ->

					expect(do @subject).to.eventually.have.length(1).and.satisfy (rows) ->

						_.first(rows).color == 'orange'
			context 'which is invalid', ->

				before ->

					@args = [{invalid: false}]

				it 'throws an error', ->

					expect(do @subject).to.eventually.be.rejectedWith(Error);
			context 'and adding another one', ->

				before (next) ->

					@args = [{length: 14, "_rev": 3}]
					runQuery """

						INSERT INTO
						sprints
						(_id, _rev, title, color, start, length)
						VALUES
						(3, 1, 'Sprint C', 'green', '2014-01-01', 3)
					""", next
				it 'returns one sprint', ->

					expect(do @subject).to.eventually.have.length(1)

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
		context 'when specifying a combination of both', ->

			before (next) ->

				@args = [{length: 14}, {'color': 1}]
				runQuery """

					INSERT INTO
					sprints
					(_id, _rev, title, color, start, length)
					VALUES
					(3, 1, 'Sprint C', 'green', '2014-01-01', 3)
				""", next
			it 'returns filtered sorted sprints', ->

				expect(do @subject).to.eventually.have.length(2).and.satisfy (rows) ->

					_.pluck(rows, 'color')[0] == 'orange'