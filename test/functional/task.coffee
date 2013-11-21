casper = require('casper').create()

taskId = '528c9639eab8b32b76efac0d'
taskUrl = "http://localhost:8000/task/#{taskId}"

casper.start taskUrl 

casper.viewport 1024, 768

casper.then ->

	casper.test.info 'Verify displayed values:'
	values = casper.getFormValues('#content form')
	casper.test.assertEquals values.summary, 'Test Task A', 'Summary field correct.'
	casper.test.assertEquals values.description, 'Task A description', 'Description field correct.'
	casper.test.assertEquals values.initial_estimation, '3', 'Initial estimation field correct.'
	casper.test.assertEquals values.remaining_time, '10', 'Remaining time field correct.'
	casper.test.assertEquals values.time_spent, '0', 'Time spent field correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'red', 'Color button correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='story_id']").text, 'Test Story A', 'Story button correct.'

casper.then ->

	casper.test.info 'Test color selector:'
	casper.click "button[name='color']"
	casper.test.assertVisible '#color-selector .content', 'Color popup appeared.'
	casper.click "#color-selector .green"
	casper.test.assertNotVisible '#color-selector .content', 'Color popup disappeared.'
	casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.then ->

	casper.test.info 'Test story selector:'
	casper.click "button[name='story_id']"
	casper.waitForResource taskUrl, ->
		
		casper.test.assertVisible '#story-selector .content', 'Story popup appeared.'
		nLines = this.evaluate ->

			$('#story-selector .content .line').length
		casper.test.assertEquals nLines, 2, '2 lines visible.'
		casper.click '#story-selector .content .line:nth-child(2)'
		casper.test.assertNotVisible '#story-selector .content', 'Story popup disappeared.'
		casper.test.assertEquals casper.getElementInfo("button[name='story_id']").text, 'Test Story B', 'Story button correct.'

casper.then ->

	casper.test.info 'Test remaining time field:'
	casper.click "button[name='remaining_time-index']"
	casper.test.assertVisible '#remaining_time-index .content', 'Datepicker appeared.'
	casper.test.assertMatch casper.getElementInfo("#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(2)").attributes.class, /ui-state-disabled/, 'Non-sprint days are not selectable.'
	casper.click "#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(3) a"
	casper.test.assertNotVisible '#remaining_time-index .content', 'Datepicker disappeared.'
	casper.test.assertEquals casper.getElementInfo("button[name='remaining_time-index']").text, '01/01/13', 'Date button correct.'
	casper.test.assertField 'remaining_time', '1', 'Remaining time field correct.'
	casper.fill 'form', {'remaining_time': '5'}
	casper.wait 500, ->

		casper.click "button[name='remaining_time-index']"
		casper.click "#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(4) a"
		casper.test.assertField 'remaining_time', '5', 'Remaining time field correct.'

casper.then ->

	casper.test.info 'Test time spent field:'
	casper.click "button[name='time_spent-index']"
	casper.test.assertVisible '#time_spent-index .content', 'Datepicker appeared.'	
	casper.click "#time_spent-index .content tr:nth-of-type(1) td:nth-of-type(3) a"
	casper.test.assertNotVisible '#time_spent-index .content', 'Datepicker disappeared.'
	casper.test.assertEquals casper.getElementInfo("button[name='time_spent-index']").text, '01/01/13', 'Date button correct.'
	casper.test.assertField 'time_spent', '2', 'Time spent field correct.'

casper.then ->

	casper.test.info 'Fill summary, description & initial estimation fields, then verify values after reload.'
	casper.fill '#content form', 

		'summary': 'Edited summary'
		'description': 'Edited description'
		'initial_estimation': '7'

	casper.wait 500, ->
	
		casper.reload ->

			casper.test.assertField 'summary', 'Edited summary', 'Summary field correct.'
			casper.test.assertEquals casper.getHTML('#breadcrumb-bar span.breadcrumb.task.selected'), 'Edited summary', 'Breadcrumb text correct.'
			casper.test.assertField 'description', 'Edited description', 'Description field correct.'
			casper.test.assertField 'initial_estimation', '7', 'Initial estimation field correct.'
			casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'
			casper.test.assertEquals casper.getElementInfo("button[name='story_id']").text, 'Test Story B', 'Story button correct.'

casper.run ->

	@test.done 30
	@test.renderResults true