pg = require('pg')
_ = require('underscore')._
chai = require('chai')
chaiAsPromised = require('chai-as-promised')
exec = require('child_process').exec
postgres = require('../../postgres.js')

assert = chai.assert
expect = chai.expect
chai.use chaiAsPromised

query = (queryString, next) ->

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

		before (next) ->

			query """

				INSERT INTO 
				sprints 
				(_id, _rev, title, description, color, start, length) 
				VALUES
				(1, 3, 'Sprint A', 'bla', 'orange', '2013-01-14', 14),
				(2, 6, 'Sprint B', 'blub', 'red', '2013-01-15', 14)
			""", next

		after (next) -> 

			query 'DELETE FROM sprints', next

		beforeEach ->

			@subject = ->

				postgres.findSprints @args...

		it 'returns an array', ->

			expect(do @subject).to.eventually.be.an('Array')
		it 'returns two sprints', ->

			expect(do @subject).to.eventually.have.length(2)

		context 'when using a valid filter parameter', ->
		
			beforeEach ->

				@args = [{color: 'orange'}]

			it 'return one orange sprint', ->

				expect(do @subject).to.eventually.have.length(1)
				expect(do @subject).to.eventually.satisfy (rows) ->

					_.first(rows).color == 'orange'