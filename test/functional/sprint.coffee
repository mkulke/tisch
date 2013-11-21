casper = require('casper').create()

sprintId = '528c95f4eab8b32b76efac0b'
sprintUrl = "http://localhost:8000/sprint/#{sprintId}"

casper.start sprintUrl 

casper.viewport 1024, 768

casper.then ->

	casper.test.info 'Verify displayed values:'
	values = casper.getFormValues('#content form')
	casper.test.assertEquals values.title, 'Test Sprint A', 'Title field correct.'
	casper.test.assertEquals values.description, 'Sprint A description', 'Description field correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'blue', 'Color button correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='start']").text, '01/01/13', 'Date button correct.'

casper.then ->

	casper.test.info 'Test color selector:'
	casper.click "button[name='color']"
	casper.test.assertVisible '#color-selector .content', 'Color popup appeared.'
	casper.click "#color-selector .green"
	casper.test.assertNotVisible '#color-selector .content', 'Color popup disappeared.'
	casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.then ->

	casper.test.info 'Change start date:'
	casper.click "button[name='start']"
	casper.test.assertVisible '#start .content', 'Datepicker appeared.'	
	casper.click "#start .content tr:nth-of-type(1) td:nth-of-type(4) a"
	casper.test.assertNotVisible '#start .content', 'Datepicker disappeared.'
	casper.test.assertEquals casper.getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'

casper.then ->

	casper.test.info 'Fill title & description fields, then verify values after reload:'
	casper.fill '#content form', 

		'title': 'Edited title'
		'description': 'Edited description'
	casper.wait 500, ->
	
		casper.reload ->

			casper.test.assertField 'title', 'Edited title', 'Title field correct.'
			casper.test.assertEquals casper.getHTML('#breadcrumb-bar span.breadcrumb.sprint.selected'), 'Edited title', 'Breadcrumb text correct.'
			casper.test.assertField 'description', 'Edited description', 'Description field correct.'
			casper.test.assertEquals casper.getElementInfo("button[name='start']").text, '01/02/13', 'Date button correct.'
			casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.run ->

	@test.done 15
	@test.renderResults true