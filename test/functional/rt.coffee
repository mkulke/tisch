casper = require('casper')
casper1 = casper.create()
casper2 = casper.create()

throttle = 500
dragDelay = 150
sync = 1000

sprintId = '528c95f4eab8b32b76efac0b'
url = (type, id) -> "http://localhost:8000/#{type}/#{id}"

setViewport = ->

	@viewport 1024, 768

createDoneFn = ->

	isDone = false
	(value) ->

		if value? then isDone = value
		else isDone

casper1.done = do createDoneFn
casper2.done = do createDoneFn

waitFor = (whom, fn) -> -> @wait sync, -> @waitFor whom.done, fn
waitFor1 = (fn) -> waitFor casper1, fn
waitFor2 = (fn) -> waitFor casper2, fn

imDone = -> @done true

moveChild = (from, to, url, fn) -> 

	infoTo = @getElementInfo "ul#well li:nth-of-type(#{to}) .header"
	infoFrom = @getElementInfo "ul#well li:nth-of-type(#{from}) .header"

	@mouse.down(infoFrom.x + infoFrom.width / 2, infoFrom.y + infoFrom.height / 2)
	@wait dragDelay, ->

		@mouse.move(infoTo.x + infoTo.width / 2, infoTo.y + infoTo.height / 2)
		@mouse.up(infoTo.x + infoTo.width / 2, infoTo.y + infoTo.height / 2)
		@waitForResource url, fn

casper1.test.info "Open the index page on 2 clients."

casper1.start url('sprint', sprintId), setViewport
casper2.start url('sprint', sprintId), setViewport

casper1.then ->

	@test.info 'Edit sprint title field on client #1:'
	@fill '#content form', 

		'title': 'Edited tütle'
	@wait throttle, ->

		@waitForResource url('sprint', sprintId), imDone

casper2.then waitFor1 ->

	@test.assertField 'title', 'Edited tütle', 'Title field on client #2 correct.'
	@test.info 'Move story from pos 2 to pos 1 on client #2:'
	moveChild.call @, 2, 1, url('sprint', sprintId), imDone

casper1.then waitFor2 ->

	@test.assertField 'title-0', 'Test Story B', 'Pos 1 Title field on client #1 correct.'
	@test.info 'Create Story on client #1:'
	@click '#button-bar input.button.add'
	@waitForResource url('sprint', sprintId), imDone

casper2.then waitFor1 ->

	@test.assertEval -> 

		document.querySelectorAll('ul#well li.panel').length == 3
	,'3 Story panels visible on client #2.'
	@test.info 'Edit description for new Story client #2:'
	@fill '#content form', 

		'description-2': 'déscription'

casper1.then waitFor2 ->

	@test.assertField 'description-2', 'déscription', 'Description field for new Story on client #1 correct.'
	@test.info 'Remove Story on client #2:'
	@click 'ul#well li.panel:nth-of-type(3) input.button.remove'
	@click '#confirm-dialog input.button.confirm'
	@waitForResource url('sprint', sprintId), imDone

casper2.then waitFor1 ->

	@test.assertEval ->

		document.querySelectorAll('ul#well li.panel').length == 2
	, '2 Story panels visible on client #1.'

casper1.then waitFor2 ->

casper1.run()
casper2.run()