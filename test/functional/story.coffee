casper = require('casper').create()

storyId = '528c961beab8b32b76efac0c'
storyUrl = "http://localhost:8000/story/#{storyId}"
throttle = 500
dragDelay = 150

casper.start storyUrl 

casper.viewport 1024, 768

casper.then ->

	@test.info 'Verify page content:'
	values = @getFormValues('#content form')
	@test.assertEquals values.title, 'Test Story A', 'Title field correct.'
	@test.assertEquals values.description, 'Story A description', 'Description field correct.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'yellow', 'Color button correct.'
	#@test.assertEquals @getElementInfo("button[name='start']").text, '01/01/13', 'Date button correct.'
	@test.assertEval ->

			document.querySelectorAll('ul#well li.panel').length == 2;
	, '1 Task panel visible.'
	@test.assertField 'summary-0', 'Test Task A', 'Task 1 summary field correct.'
	@test.assertField 'description-0', 'Task A description', 'Task 1 description field correct.'
	#@test.assertDoesntExist 'ul#well li.panel:nth-of-type(1) .header .stats img', 'Story 1 stats picture does not exist.'
	#@test.assertExist "ul#well li.panel:nth-of-type(2) .header .stats img[src='/clock_white_30.png']", 'Story 2 stats picture is a clock.'###

casper.then ->

	@test.info 'Test color selector:'
	@click "button[name='color']"
	@test.assertVisible '#color-selector .content', 'Color popup appeared.'
	@click "#color-selector .green"
	@test.assertNotVisible '#color-selector .content', 'Color popup disappeared.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

###casper.then ->

	@test.info 'Change end date:'
	@click "button[name='length']"
	@test.assertVisible '#length .content', 'Datepicker appeared.'	
	@click "#length .content tr:nth-of-type(2) td:nth-of-type(5) a"
	@test.assertNotVisible '#length .content', 'Datepicker disappeared.'
	@test.assertEquals @getElementInfo("button[name='length']").text, '01/10/13', 'Date button correct.'

casper.then ->

	@test.info 'Change start date:'
	@click "button[name='start']"
	@test.assertVisible '#start .content', 'Datepicker appeared.'	
	@click "#start .content tr:nth-of-type(1) td:nth-of-type(4) a"
	@test.assertNotVisible '#start .content', 'Datepicker disappeared.'
	@test.assertEquals @getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'###

casper.then ->

	@test.info 'Create and remove task:'
	@click '#button-bar input.button.add'
	@waitForResource storyUrl, ->

		@test.assertEval ->

				document.querySelectorAll('ul#well li.panel').length == 3;
		, '3 Task panels visible.'
		@click 'ul#well li.panel:nth-of-type(3) input.button.remove'
		@test.assertVisible '#confirm-dialog', 'Confirmation dialog appeared'
		@click '#confirm-dialog input.button.confirm'
		@test.assertNotVisible '#confirm-dialog', 'Confirmation dialog disappeared'
		@waitForResource storyUrl, ->

			@test.assertEval ->

				document.querySelectorAll('ul#well li.panel').length == 2;
			, '2 Task panels visible.'	

casper.then ->

	@test.info 'Move task 2 to position 1:'

	info1 = @getElementInfo('ul#well li:nth-of-type(1) .header');
	info2 = @getElementInfo('ul#well li:nth-of-type(2) .header');

	@mouse.down(info2.x + info2.width / 2, info2.y + info2.height / 2)
	@wait dragDelay, ->

		@mouse.move(info1.x + info1.width / 2, info1.y + info1.height / 2)
		@mouse.up(info1.x + info1.width / 2, info1.y + info1.height / 2)
		@test.assertField 'summary-0', 'Test Task B', 'Summary field correct.'

casper.then ->

	@test.info 'Open stats dialog and verify contents:'
	@click '#button-bar .button.stats'
	@test.assertVisible '#stats-dialog', 'Stats dialog appeared.'
	@test.assertEquals @getHTML('#stats-dialog .stat.no-of-tasks span.value'), '2', 'Correct number of tasks value.'
	@test.assertEquals @getHTML('#stats-dialog .stat.remaining-time span.value'), '18.5', 'Correct remaining time value.'
	@test.assertEquals @getHTML('#stats-dialog .stat.time-spent span.value'), '6', 'Correct time spent value.'
	@click '#stats-dialog .popup-buttons .button.close'
	@test.assertNotVisible '#stats-dialog', 'Stats dialog disappeared.'

casper.then ->

	@test.info 'Fill several throttled fields, then verify page content after reload:'
	@fill '#content form', 

		'title': 'Edited title'
		'description': 'Edited description'
		'estimation': 8.99
		'summary-0': 'Edited task summary'
		'description-0': 'Edited task description'
	@wait throttle, ->
	
		@waitForResource storyUrl, ->

			@reload ->

				@test.assertField 'title', 'Edited title', 'Title field correct.'
				@test.assertEquals @getHTML('#breadcrumb-bar span.breadcrumb.story.selected'), 'Edited title', 'Breadcrumb text correct.'
				@test.assertField 'description', 'Edited description', 'Description field correct.'
				@test.assertField 'estimation', '8.99', 'Initial estimation field correct.'
				#@test.assertEquals @getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'
				#@test.assertEquals @getElementInfo("button[name='length']").text, '01/11/13', 'Date button correct.'
				@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'
				@test.assertField 'summary-1', 'Test Task A', 'Task summary field correct.'
				@test.assertField 'summary-0', 'Edited task summary', 'Task summary field correct.'
				@test.assertField 'description-0', 'Edited task description', 'Task description field correct.'

casper.run ->

	@test.done 27
	@test.renderResults true