casper = require('casper').create()

taskId = '528c9639eab8b32b76efac0d'
taskUrl = "http://localhost:8000/task/#{taskId}"
throttle = 500

casper.start taskUrl 

casper.viewport 1024, 768

casper.then ->

	@test.info 'Verify displayed values:'
	values = @getFormValues('#content form')
	@test.assertEquals values.summary, 'Test Task A', 'Summary field correct.'
	@test.assertEquals values.description, 'Task A description', 'Description field correct.'
	@test.assertEquals values.initial_estimation, '3', 'Initial estimation field correct.'
	@test.assertEquals values.remaining_time, '10', 'Remaining time field correct.'
	@test.assertEquals values.time_spent, '0', 'Time spent field correct.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'red', 'Color button correct.'
	@test.assertEquals @getElementInfo("button[name='story_id']").text, 'Test Story A', 'Story button correct.'

casper.then ->

	@test.info 'Test color selector:'
	@click "button[name='color']"
	@test.assertVisible '#color-selector .content', 'Color popup appeared.'
	@click "#color-selector .green"
	@test.assertNotVisible '#color-selector .content', 'Color popup disappeared.'
	@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'

casper.then ->

	@test.info 'Test story selector:'
	@click "button[name='story_id']"
	@waitForResource taskUrl, ->
		
		@test.assertVisible '#story-selector .content', 'Story popup appeared.'
		nLines = this.evaluate ->

			$('#story-selector .content .line').length
		@test.assertEquals nLines, 2, '2 lines visible.'
		@click '#story-selector .content .line:nth-child(2)'
		@test.assertNotVisible '#story-selector .content', 'Story popup disappeared.'
		@test.assertEquals @getElementInfo("button[name='story_id']").text, 'Test Story B', 'Story button correct.'

casper.then ->

	@test.info 'Test remaining time field:'
	@click "button[name='remaining_time-index']"
	@test.assertVisible '#remaining_time-index .content', 'Datepicker appeared.'
	@test.assertMatch @getElementInfo("#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(2)").attributes.class, /ui-state-disabled/, 'Non-sprint days are not selectable.'
	@click "#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(3) a"
	@test.assertNotVisible '#remaining_time-index .content', 'Datepicker disappeared.'
	@test.assertEquals @getElementInfo("button[name='remaining_time-index']").text, '01/01/13', 'Date button correct.'
	@test.assertField 'remaining_time', '1', 'Remaining time field correct.'
	@fill 'form', {'remaining_time': '5'}
	@wait throttle, ->

		@click "button[name='remaining_time-index']"
		@click "#remaining_time-index .content tr:nth-of-type(1) td:nth-of-type(4) a"
		@test.assertField 'remaining_time', '5', 'Remaining time field correct.'

casper.then ->

	@test.info 'Test time spent field:'
	@click "button[name='time_spent-index']"
	@test.assertVisible '#time_spent-index .content', 'Datepicker appeared.'	
	@click "#time_spent-index .content tr:nth-of-type(1) td:nth-of-type(3) a"
	@test.assertNotVisible '#time_spent-index .content', 'Datepicker disappeared.'
	@test.assertEquals @getElementInfo("button[name='time_spent-index']").text, '01/01/13', 'Date button correct.'
	@test.assertField 'time_spent', '2', 'Time spent field correct.'

casper.then ->

	@test.info 'Fill summary, description & initial estimation fields, then verify values after reload.'
	@fill '#content form', 

		'summary': 'Edited summary'
		'description': 'Edited description'
		'initial_estimation': '7'

	@wait throttle, ->
	
		@waitForResource taskUrl, ->
			
			@reload ->

				@test.assertField 'summary', 'Edited summary', 'Summary field correct.'
				@test.assertEquals @getHTML('#breadcrumb-bar span.breadcrumb.task.selected'), 'Edited summary', 'Breadcrumb text correct.'
				@test.assertField 'description', 'Edited description', 'Description field correct.'
				@test.assertField 'initial_estimation', '7', 'Initial estimation field correct.'
				@test.assertEquals @getElementInfo("button[name='color']").attributes.class, 'green', 'Color button correct.'
				@test.assertEquals @getElementInfo("button[name='story_id']").text, 'Test Story B', 'Story button correct.'

casper.run ->

	@test.done 30
	@test.renderResults true