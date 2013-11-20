casper = require('casper').create()

taskId = '528c9639eab8b32b76efac0d'
taskUrl = "http://localhost:8000/task/#{taskId}"

casper.start taskUrl 

casper.viewport 1024, 768

casper.then ->

	casper.test.info "Verify displayed values:"
	values = casper.getFormValues('form')
	casper.test.assertEquals values.summary, 'Test Task A', 'Summary field correct.'
	casper.test.assertEquals values.description, 'Task A description', 'Description field correct.'
	casper.test.assertEquals values.initial_estimation, '3', 'Initial estimation field correct.'
	casper.test.assertEquals values.remaining_time, '10', 'Remaining time field correct.'
	casper.test.assertEquals values.time_spent, '0', 'Time spent field correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='color']").attributes.class, 'red', 'Color button correct.'
	casper.test.assertEquals casper.getElementInfo("button[name='story_id']").text, 'Test Story A', 'Story button correct.'

casper.run ->

	@test.done 7
	@test.renderResults true