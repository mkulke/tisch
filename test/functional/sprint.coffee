casper = require('casper').create()

sprintId = '528c95f4eab8b32b76efac0b'
sprintUrl = "http://localhost:8000/sprint/#{sprintId}"
throttle = 500

casper.start sprintUrl 

casper.viewport 1024, 768

casper.then ->

	@test.info 'Verify displayed values:'
	values = @getFormValues('#content form')
	@test.assertEquals values.title, 'Test Sprint A', 'Title field correct.'
	@test.assertEquals values.description, 'Sprint A description', 'Description field correct.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'blue', 'Color button correct.'
	@test.assertEquals @getElementInfo("button[name='start']").text, '01/01/13', 'Date button correct.'

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

	@test.info 'Fill title & description fields, then verify values after reload:'
	@fill '#content form', 

		'title': 'Edited title'
		'description': 'Edited description'
	@wait throttle, ->
	
		@waitForResource sprintUrl, ->
			
			@reload ->

				@test.assertField 'title', 'Edited title', 'Title field correct.'
				@test.assertEquals @getHTML('#breadcrumb-bar span.breadcrumb.sprint.selected'), 'Edited title', 'Breadcrumb text correct.'
				@test.assertField 'description', 'Edited description', 'Description field correct.'
				@test.assertEquals @getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'
				@test.assertEquals @getElementInfo("button[name='length']").text, '01/11/13', 'Date button correct.'
				@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.run ->

	@test.done 19
	@test.renderResults true