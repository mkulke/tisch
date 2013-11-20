casper = require('casper').create()

taskId = '528c9639eab8b32b76efac0d'
taskUrl = "http://localhost:8000/task/#{taskId}"

casper.start taskUrl 

casper.viewport 1024, 768

casper.then ->

	casper.test.info 'Verify displayed values:'
	values = casper.getFormValues('form')
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

casper.run ->

	@test.done 14
	@test.renderResults true