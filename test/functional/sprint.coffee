casper = require('casper').create()

sprintId = '528c95f4eab8b32b76efac0b'
sprintUrl = "http://localhost:8000/sprint/#{sprintId}"
throttle = 500
dragDelay = 150

casper.start sprintUrl 

casper.viewport 1024, 768

casper.then ->

	@test.info 'Verify page content:'
	values = @getFormValues('#content form')
	@test.assertEquals values.title, 'Test Sprint A', 'Title field correct.'
	@test.assertEquals values.description, 'Sprint A description', 'Description field correct.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'blue', 'Color button correct.'
	@test.assertEquals @getElementInfo("button[name='start']").text, '01/01/13', 'Date button correct.'
	@test.assertEval ->

			document.querySelectorAll('ul#well li.panel').length == 2;
	, '2 Story panels visible.'
	@test.assertField 'title-0', 'Test Story A', 'Story 1 title field correct.'
	@test.assertField 'description-0', 'Story A description', 'Story 1 description field correct.'
	@test.assertDoesntExist 'ul#well li.panel:nth-of-type(1) .header .stats img', 'Story 1 stats picture does not exist.'
	@test.assertField 'title-1', 'Test Story B', 'Story 2 title field correct.'
	@test.assertField 'description-1', 'Story B description', 'Story 2 description field correct.'
	@test.assertExist "ul#well li.panel:nth-of-type(2) .header .stats img[src='/clock_white_30.png']", 'Story 2 stats picture is a clock.'

casper.then ->

	@test.info 'Test color selector:'
	@click "button[name='color']"
	@test.assertVisible '#color-selector .content', 'Color popup appeared.'
	@click "#color-selector .green"
	@test.assertNotVisible '#color-selector .content', 'Color popup disappeared.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.then ->

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
	@test.assertEquals @getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'

casper.then ->

	@test.info 'Move story 2 to position 1:'

	info1 = @getElementInfo('ul#well li:nth-of-type(1) .header');
	info2 = @getElementInfo('ul#well li:nth-of-type(2) .header');

	@mouse.down(info2.x + info2.width / 2, info2.y + info2.height / 2)
	@wait dragDelay, ->

		@mouse.move(info1.x + info1.width / 2, info1.y + info1.height / 2)
		@mouse.up(info1.x + info1.width / 2, info1.y + info1.height / 2)
		@test.assertField 'title-0', 'Test Story B', 'Title field correct.'

casper.then ->

	@test.info 'Fill several throttled fields, then verify page content after reload:'
	@fill '#content form', 

		'title': 'Edited title'
		'description': 'Edited description'
		'title-1': 'Edited story title'
		'description-1': 'Edited story description'
	@wait throttle, ->
	
		@waitForResource sprintUrl, ->

			@reload ->

				@test.assertField 'title', 'Edited title', 'Title field correct.'
				@test.assertEquals @getHTML('#breadcrumb-bar span.breadcrumb.sprint.selected'), 'Edited title', 'Breadcrumb text correct.'
				@test.assertField 'description', 'Edited description', 'Description field correct.'
				@test.assertEquals @getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'
				@test.assertEquals @getElementInfo("button[name='length']").text, '01/11/13', 'Date button correct.'
				@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'
				@test.assertField 'title-0', 'Test Story B', 'Story title field correct.'
				@test.assertField 'title-1', 'Edited story title', 'Story title field correct.'
				@test.assertField 'description-1', 'Edited story description', 'Story description field correct.'

casper.run ->

	@test.done 30
	@test.renderResults true