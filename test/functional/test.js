
var casper = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

var indexUrl = 'http://localhost:8000/';
var sprintUrl = indexUrl + 'sprint/51ac972325dfbc3750000001';
var story1Id, story2Id, story1Url, story2Url, story3Id, story3Url, task1Id, task2Id;

var stories = {};

casper.test.info("Open the sprint test page:");

casper.start(sprintUrl);

casper.viewport(1024, 768);

casper.then(function() {

	this.test.assertDoesntExist('#panel-container .panel', 'No story visible.');

	casper.test.info("Click the add button 2 times:");

	this.click('#add-button');
	this.click('#add-button');
	this.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 2;
		}, '2 story panels are visible.');

		story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
		story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

		this.test.assertNotVisible('#' + story1Id + ' .remaining', 'No remaining indictor on story 1 visible.');
		this.test.assertNotVisible('#' + story1Id + ' .done', 'No done indictor on story 1 visible.');
	});
});

casper.then(function() {

  casper.test.info("Edit title & description of story 1 (and wait 2s):");

  this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');
  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');

	this.wait(2000, function () {

		this.capture('test.png');

		this.waitForResource(sprintUrl, function() {

			this.test.assertNotVisible('#alert-panel', 'Alert panel is not visible.');
		});
	});
});

casper.then(function() {

	casper.test.info("Reload the page:");

	this.reload(function() {

		this.test.assertEquals(this.getElementAttribute('#' + story1Id + ' input[name="title"]', 'value'), 'New Story 1', 'Story title changes are kept.');
		this.test.assertEquals(this.getHTML('#' + story1Id + ' textarea[name="description"]'), 'Description of story 1.', 'Story description changes are kept.');
	});
});

casper.then(function() {

	casper.test.info("Move story 2 to position 1:");

	var info1 = this.getElementInfo('#' + story1Id + ' .header');
	var info2 = this.getElementInfo('#' + story2Id + ' .header');

	this.mouse.down(info2.x + info2.width / 2, info2.y + info2.height / 2);
	this.mouse.move(info1.x + info1.width / 2, info1.y + info1.height / 2);
	this.mouse.up(info1.x + info1.width / 2, info1.y + info1.height / 2);

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is on position 1.');

	casper.test.info("Reload page:");

	this.reload(function() {

		this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is still on position 1.');
	});
});

casper.then(function() {

	casper.test.info("Double-click on the header of story 1:");

	this.mouseEvent('dblclick', '#' + story1Id + ' .header');

	story1Url = 'http://localhost:8000/story/' + story1Id.substr('uuid-'.length);

	casper.waitForResource(story1Url, function() {

		this.test.assertEquals(this.getElementAttribute('#' + story1Id + ' input[name="title"]', 'value'), 'New Story 1', 'Story title is correct.');
		this.test.assertEquals(this.getHTML('#' + story1Id + ' textarea[name="description"]'), 'Description of story 1.', 'Story description is correct.');
		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length === 0;
		}, 'No panels are visible.');
	});
});

casper.then(function() {

  this.test.info('Click the add button 4 times:');

	this.click('#add-button');
	this.click('#add-button');
	this.click('#add-button');
	this.click('#add-button');

	this.waitForResource(story1Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 4;
		}, '4 task panels are visible.');

		task1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
		task2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

		this.test.assertVisible('#' + task1Id + ' .remaining', 'Remaining indictor on task 1 visible.');
		this.test.assertEquals(this.getHTML('#' + task1Id + ' span.remaining.text'), '1', 'Remaining time of task 1 is 1.');
		this.test.assertNotVisible('#' + task1Id + ' .done', 'No done indictor on task 1 visible.');
	});
});

casper.then(function() {

  casper.test.info("Edit title & description of task 2 (and wait 2s):");

  this.sendKeys('#' + task2Id + ' input[name="summary"]', ' 2');
	this.sendKeys('#' + task2Id + ' textarea[name="description"]', 'Description of task 2.');

	this.wait(2000, function () {

		this.test.assertNotVisible('#alert-panel', 'Alert panel is not visible.');
	});
});

casper.then(function() {

	casper.test.info("Reload the page:");

	this.reload(function() {

		this.test.assertEquals(this.getElementAttribute('#' + task2Id + ' input[name="summary"]', 'value'), 'New Task 2', 'Task summary changes are kept.');
		this.test.assertEquals(this.getHTML('#' + task2Id + ' textarea[name="description"]'), 'Description of task 2.', 'Task description changes are kept.');
	});
});

casper.then(function() {

	casper.test.info("Move task 1 to position 2:");

	var info1 = this.getElementInfo('#' + task1Id + ' .header');
	var info2 = this.getElementInfo('#' + task2Id + ' .header');

	this.mouse.down(info1.x + info1.width / 2, info1.y + info1.height / 2);
	this.mouse.move(info2.x + info2.width / 2, info2.y + info2.height / 2);
	this.mouse.up(info2.x + info2.width / 2, info2.y + info2.height / 2);

	this.test.assertEquals(task1Id, this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id'), 'Task 1 is on position 2.');

	casper.test.info("Reload page:");

	this.reload(function() {

		this.test.assertEquals(task1Id, this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id'), 'Task 1 is still on position 2.');
	});
});

casper.then(function() {

  casper.test.info("Click the remove button on task 1:");

  this.click('#' + task1Id + ' .remove.button');
  this.waitForResource(story1Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 3;
		}, '3 task panels are visible.');
	});
});

casper.then(function() {

	casper.test.info("Double-click on the header of task 2:");

	this.mouseEvent('dblclick', '#' + task2Id + ' .header');

	task2Url = 'http://localhost:8000/task/' + task2Id.substr('uuid-'.length);

	casper.waitForResource(task2Url, function() {

		this.test.assertEquals(this.getElementAttribute('#' + task2Id + ' input[name="summary"]', 'value'), 'New Task 2', 'Task summary is correct.');
		this.test.assertEquals(this.getHTML('#' + task2Id + ' textarea[name="description"]'), 'Description of task 2.', 'Task description is correct.');
		this.test.assertEquals(this.getHTML('#story-selector .selected'), 'New Story 1', 'Story assignment is correct.');

		this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('blue') != -1, 'Header color is set to blue.');
	});
});

casper.then(function() {

	this.test.info("Click on color selector:");

	this.click('#color-selector .selected');
	this.test.assertVisible('#color-selector .content', 'Color dialog appeared.');

	this.test.info("Click on purple box:");
	this.click('#color-selector .purple');

	casper.waitForResource(task2Url, function() {

		this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('purple') != -1, 'Header color is set to purple.');
	});
});

casper.then(function(){

	this.test.info('Add an illegal character into the "Initial Estimation" field (and wait 1.5s):');

	this.sendKeys('.main-panel input[name="initial_estimation"]', 'a');

	this.wait(1500, function() {

		this.test.assertVisible('.error-popup .content', 'Error popup appeared.');
	});
});

casper.then(function(){

	this.test.info('Fill the time fields (and wait 1.5s):');

	this.fill('form', {initial_estimation: '', remaining_time: '', time_spent: ''}, false);

	this.sendKeys('.main-panel input[name="initial_estimation"]', '99.99');
	this.sendKeys('.main-panel input[name="remaining_time"]', '0');
	this.sendKeys('.main-panel input[name="time_spent"]', '33.3');

	this.wait(1500, function() {

		this.test.assertNotVisible('.error-popup .content', 'No error popup visible.');
		this.test.assertNotVisible('#alert-panel', 'Alert panel not visible.');	
	});
});

casper.then(function(){

	this.test.info('Reload the page:');

	this.reload(function() {

		this.test.assertEquals(this.getElementAttribute('.main-panel input[name="initial_estimation"]', 'value'), '99.99', 'Initial estimation is kept.');
		this.test.assertEquals(this.getElementAttribute('.main-panel input[name="remaining_time"]', 'value'), '0', 'Remaining time is kept.');
		this.test.assertEquals(this.getElementAttribute('.main-panel input[name="time_spent"]', 'value'), '33.3', 'Time spent is kept.');
	});
});

casper.then(function() {

	this.test.info("Click on story selector:");

	this.click('#story-selector .selected');

	casper.waitForResource(task2Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#story-selector .content div').length == 2;
		}, 'Selector has 2 lines.');

		this.test.assertSelectorHasText('#story-selector .content div:nth-child(1)', 'New Story', 'Line 1 in selector is correct.');
		this.test.assertSelectorHasText('#story-selector .content div:nth-child(2)', 'New Story 1', 'Line 2 in selector is correct.');	
	});
});

casper.then(function() {

	this.test.info('Click line 1 in selector:');
	
	this.click('#story-selector .content div:nth-child(1)');

	casper.waitForResource(task2Url, function() {

		this.test.assertNotVisible('.error-popup .content', 'No error popup visible.');
	});
});

casper.then(function() {

  casper.test.info('Go back:');

  this.back();

  casper.waitForResource(story1Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 2;
		}, '2 task panels are visible.');
  });	
});

casper.then(function() {

  casper.test.info('Go back:');

  this.back();

  casper.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 2;
		}, '2 story panels are visible.');

		this.test.assertVisible('#' + story1Id + ' .remaining', 'Remaining indicator on story 1 visible.');
		this.test.assertEquals(this.getHTML('#' + story1Id + ' span.remaining.text'), '2', 'Remaining time of story 1 is 2.');
		this.test.assertNotVisible('#' + story1Id + ' .done', 'No done indictor on story 1 visible.');

		this.test.assertNotVisible('#' + story2Id + ' .remaining', 'No remaining indicator on story 2 visible.');
		this.test.assertVisible('#' + story2Id + ' .done', 'Done indictor on story 2 visible.');		
	});
});

casper.then(function() {

	casper.test.info("Double-click on the header of story 2:");

	this.mouseEvent('dblclick', '#' + story2Id + ' .header');

	story2Url = 'http://localhost:8000/story/' + story2Id.substr('uuid-'.length);

	casper.waitForResource(story2Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 1;
		}, '1 task panel is visible.');
		this.test.assert(this.getElementAttribute('#' + task2Id + ' .header', 'class').split(' ').indexOf('purple') != -1, 'Header color of task 2 is purple.');
	});
});

casper.then(function() {

  casper.test.info('Go back:');

  this.back();

  casper.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 2;
		}, '2 story panels are visible.');
	});
});

casper.then(function() {

  casper.test.info("Click the remove button on story 1:");

  this.click('#' + story1Id + ' .remove.button');
  this.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 1;
		}, '1 story panel is visible.');
  });
});

casper.then(function() {

  casper.test.info("Click the remove button on story 2:");

  this.click('#' + story2Id + ' .remove.button');
  this.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length === 0;
		}, 'No story panel is visible.');
	});
});

casper.then(function() {

	this.test.info("Click on sprint's color selector:");

	this.click('#color-selector .selected');
	this.test.assertVisible('#color-selector .content', 'Color dialog appeared.');

	this.test.info("Click on red box:");
	this.click('#color-selector .red');

	casper.waitForResource(sprintUrl, function() {

		this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('red') != -1, 'Header color is set to red.');
	});
});

casper.then(function() {

	this.test.info("Click on start date:");

	this.click('#start-selector .selected');

  this.test.assertVisible('#start-selector .content', 'Datepicker popup appeared.');

	this.test.info("Click on Jan 2nd 2013:");

	this.click('#start-selector .content tr:nth-child(1) td:nth-child(4)');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('#start-selector .content', 'Datepicker popup disappeared.');
		this.test.assertSelectorHasText('#start-selector span.selected', '1/2/13', 'Start date is set to Jan 2nd 2013.');
		this.test.assertSelectorHasText('#length-selector span.selected', '1/15/13', 'End date has been moved to Jan 15th 2013.');
	});
});

casper.then(function() {

	this.test.info("Click on end date:");

	this.click('#length-selector .selected');

  this.test.assertVisible('#length-selector .content', 'Datepicker popup appeared.');

	this.test.info("Click on Jan 1st 2013 (illegal b/c before start date):");

	this.click('#length-selector .content tr:nth-child(1) td:nth-child(3)');

  this.test.assertVisible('#length-selector .content', 'Datepicker popup did not disappear.');

	this.test.info("Click on Jan 13th 2013:");

	this.click('#length-selector .content tr:nth-child(3) td:nth-child(1)');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('#length-selector .content', 'Datepicker popup disappeared.');
		this.test.assertSelectorHasText('#length-selector span.selected', '1/13/13', 'End date is set to Jan 13th 2013.');
	});
});

// Cleanup

casper.then(function() {

	this.test.info("Reset sprint to default values:");

	this.click('#color-selector .selected');
	this.click('#color-selector .purple');

	casper.waitForResource(sprintUrl, function() {

		this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('purple') != -1, 'Header color is set to purple.');
	});
});

casper.then(function() {

	this.click('#start-selector .selected');
	this.click('#start-selector .content tr:nth-child(1) td:nth-child(3)');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertSelectorHasText('#start-selector span.selected', '1/1/13', 'Start date is set to Jan 1st 2013.');
	});
});

casper.then(function() {

	this.click('#length-selector .selected');
	this.click('#length-selector .content tr:nth-child(3) td:nth-child(2)');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertSelectorHasText('#length-selector span.selected', '1/14/13', 'End date is set to Jan 14th 2013.');
	});
});

casper.run(function() {

	this.test.done(63);
	this.test.renderResults(true);
});