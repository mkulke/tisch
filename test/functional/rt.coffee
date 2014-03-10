casper = require('casper')
casper1 = casper.create()
casper2 = casper.create()

throttle = 500
dragDelay = 150
sync = 1000

taskId = '528c9639eab8b32b76efac0d'
storyId = '528c961beab8b32b76efac0c'
sprintId = '528c95f4eab8b32b76efac0b'
url = (type, id) -> "http://localhost:8000/#{type}/#{id}"

setViewport = ->

	@viewport 1024, 768

createLock = ->

	available = false
	acquire: ->

		if available

			available = false 
			true
		else false
	release: -> 

		available = true

casper1.lock = createLock()
casper2.lock = createLock()

waitFor1 = (fn) -> 

  -> 
  	
  	@wait sync, -> 

  		@waitFor casper1.lock.acquire, fn

waitFor2 = (fn) -> 

	->
		
		@waitFor casper2.lock.acquire, fn

moveChild = (from, to, url, fn) -> 

	infoTo = @getElementInfo "ul#well li:nth-of-type(#{to}) .header"
	infoFrom = @getElementInfo "ul#well li:nth-of-type(#{from}) .header"

	@mouse.down(infoFrom.x + infoFrom.width / 2, infoFrom.y + infoFrom.height / 2)
	@wait dragDelay, ->

		@mouse.move(infoTo.x + infoTo.width / 2, infoTo.y + infoTo.height / 2)
		@mouse.up(infoTo.x + infoTo.width / 2, infoTo.y + infoTo.height / 2)
		@waitForResource url, fn

casper1.start url('sprint', sprintId), setViewport
casper2.start url('sprint', sprintId), setViewport

pairs = [

	do: ->

		@test.info 'Edit sprint title field:'
		@fill '#content form', 

			'title': 'Edited tütle'
		@wait throttle, ->

			@waitForResource url('sprint', sprintId), @lock.release		
	verify: ->

		@test.assertField 'title', 'Edited tütle', 'Title field correct.'		
,
	do: -> 

		@test.info 'Move story from pos 2 to pos 1:'
		moveChild.call @, 2, 1, url('sprint', sprintId), @lock.release
	verify: ->

		@test.assertField 'title-0', 'Test Story B', 'Title field on pos 1 correct.'
,
	do: -> 	

		@test.info 'Create Story:'
		@click '#button-bar input.button.add'
		@waitForResource url('sprint', sprintId), @lock.release
	verify: ->

		@test.assertEval -> 

			document.querySelectorAll('ul#well li.panel').length == 3
		,'3 Story panels visible.'
		@click '#button-bar input.button.stats'
		@test.assertSelectorHasText '#stats-dialog .content .textbox .stat.no-of-stories span.value', 3, 'No of stories stat correct.'
		@click '#stats-dialog .popup-buttons input.button.close'
,
	do: ->

		@test.info 'Edit description for new Story:'
		@fill '#content form', 

			'description-2': 'déscription'
		@wait throttle, ->

			@waitForResource url('sprint', sprintId), @lock.release
	verify: ->

		@test.assertField 'description-2', 'déscription', 'Description field for new Story correct.'
,
	do: ->

		@test.info 'Remove Story:'
		@click 'ul#well li.panel:nth-of-type(3) input.button.remove'
		@click '#confirm-dialog input.button.confirm'
		@waitForResource url('sprint', sprintId), @lock.release
	verify: ->

		@test.assertEval ->

			document.querySelectorAll('ul#well li.panel').length == 2
		, '2 Story panels visible.'
		@click '#button-bar input.button.stats'
		@test.assertSelectorHasText '#stats-dialog .content .textbox .stat.no-of-stories span.value', 2, 'No of stories stat correct.'
		@click '#stats-dialog .popup-buttons input.button.close'
,
	do: ->

		@open(url('task', taskId)).then @lock.release
	verify: ->

		@open(url('story', storyId)).then @lock.release
	manual_release_after_verify: true
,
	do: ->

		@test.info 'Change a Task\'s remaining time:'
		@fill '#content form', 

			'remaining_time': '11'
		@wait throttle, ->

			@waitForResource url('task', taskId), @lock.release
	verify: ->

		@test.assertSelectorHasText '.panel:nth-child(1) .header .stats .text', '11', 'Stats text correctly updated on Story view.'
,
	do: ->

		@test.info 'Deassign Task:'
		@click "button[name='story_id']"
		@waitForResource url('task', taskId), ->
	
			@click '#story-selector .content .line:nth-child(2)'
			@waitForResource url('task', taskId), @lock.release
	verify: ->

		@test.assertEval ->

			document.querySelectorAll('ul#well li.panel').length == 1
		, '1 Task panels visible.'
,
	do: ->

		@test.info 'Assign Task:'
		@click "button[name='story_id']"
		@waitForResource url('task', taskId), ->
		
			@click '#story-selector .content .line:nth-child(1)'
			@waitForResource url('task', taskId), @lock.release
	verify: ->

		@test.assertEval ->

			document.querySelectorAll('ul#well li.panel').length == 2
		, '2 Task panels visible.'
,
	do: ->

		@lock.release()
	verify: ->

		@open(url('sprint', sprintId)).then @lock.release
	manual_release_after_verify: true
, 
	do: ->

		@test.info 'Change Task\'s remaining time again:'
		@fill '#content form', 

			'remaining_time': '12'
		@wait throttle, ->

			@waitForResource url('task', taskId), @lock.release
	verify: ->

		@test.assertSelectorHasText '.panel:nth-child(2) .header .stats .text', '20.5', 'Stats text correctly updated on Sprint view.'
,
	do: ->

		@open(url('story', storyId)).then @lock.release
	verify: ->
,
	do: ->

		@test.info 'Create Task:'
		@click '#button-bar input.button.add'
		@waitForResource url('story', storyId), @lock.release
	verify: ->

		@test.assertSelectorHasText '.panel:nth-child(2) .header .stats .text', '21.5', 'Stats text correctly updated on Sprint view.'
		@click '#button-bar input.button.stats'
		@test.assertSelectorHasText '#stats-dialog .content .textbox .stat.remaining-time span.value', '21.5', 'Remaining time stat correct.'
		@click '#stats-dialog .popup-buttons input.button.close'
,
	do: ->

		@test.info 'Remove Task:'
		@click 'ul#well li.panel:nth-of-type(3) input.button.remove'
		@click '#confirm-dialog input.button.confirm'
		@waitForResource url('story', storyId), @lock.release
	verify: ->

		@test.assertSelectorHasText '.panel:nth-child(2) .header .stats .text', '20.5', 'Stats text correctly updated on Sprint view.'	
		@click '#button-bar input.button.stats'
		@test.assertSelectorHasText '#stats-dialog .content .textbox .stat.remaining-time span.value', '20.5', 'Remaining time stat correct.'
		@click '#stats-dialog .popup-buttons input.button.close'
,
	do: ->

		@test.info 'Reassign Task:'
		@open(url('task', taskId)).then ->

			@click "button[name='story_id']"
			@waitForResource url('task', taskId), ->
	
				@click '#story-selector .content .line:nth-child(2)'
				@waitForResource url('task', taskId), @lock.release
	verify: ->

		@test.assertSelectorHasText '.panel:nth-child(1) .header .stats .text', '12', 'Stats text correctly updated on Sprint view.'
,
	do: -> 

		@test.info 'Reassign Story:'
		@open(url('story', storyId)).then ->

			@click "button[name='sprint_id']"
			@waitForResource url('story', storyId), ->

				index = @evaluate ->

					$("#sprint-selector .content .line:contains('Test Sprint B')").index()

				@click "#sprint-selector .content .line:nth-child(#{index + 1})"
				@waitForResource url('story', storyId), @lock.release
	verify: ->

		@click '#button-bar input.button.stats'
		@test.assertSelectorHasText '#stats-dialog .content .textbox .stat.remaining-time span.value', '12', 'Remaining time stat correct.'
		@click '#stats-dialog .popup-buttons input.button.close'		
]

casper2.lock.release()
pairs.forEach (pair) -> 

	casper1.then waitFor2 pair.do
	casper2.then waitFor1 -> 

		pair.verify.call @
		if !pair.manual_release_after_verify then @lock.release()

#ensure the 1st casper instance (actor) does not finish before the 2nd one (verifyer)
casper1.then waitFor2 ->

casper1.run()
casper2.run ->

	@test.done 17
	@test.renderResults true