var casper = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

var indexUrl = 'http://localhost:8000/';
//var sprintUrl = indexUrl + 'sprint/51ac972325dfbc3750000001';
var sprintId, sprintUrl, story1Id, story2Id, story1Url, story2Url, story3Id, story3Url, task1Id, task2Id;

var stories = {};
var sprintIds = [];

function buildIdList() {

	var panels = $('#panel-container li.panel');
  var ids = [];

  panels.each(function() {

  	ids.push($(this).attr('id'));
  });
  return ids;	
}

casper.test.info("Open the index page:");

casper.start(indexUrl);

casper.viewport(1024, 768);

casper.then(function() {

	this.test.assertDoesntExist('.main-panel', 'No main panel visible.');
	this.test.assertExist('#logo-panel', 'Logo panel visible.');

	sprintIds = this.evaluate(buildIdList);

	this.test.info('There are ' + sprintIds.length + ' sprints visible, click the add button:');

	this.click('#add-button');

	this.waitForResource(indexUrl, function() {

		var newSprintIds = casper.evaluate(buildIdList);

		this.test.assertEquals(newSprintIds.length, sprintIds.length + 1,  'A new sprint panel appeared.');

		for (var i in newSprintIds) {

			if (!(i in sprintIds)) {

				sprintId = newSprintIds[i];
			}
		}
	});
});

// Edit Sprint panel

casper.then(function() {

  casper.test.info("Edit title & description of test sprint 1 (and wait 2s):");

  this.sendKeys('#' + sprintId + ' input[name="title"]', ' 1');
  this.sendKeys('#' + sprintId + ' textarea[name="description"]', '1 ');

	this.wait(2000, function () {

		this.waitForResource(indexUrl, function() {

			this.test.assertNotVisible('#alert-panel', 'Alert panel is not visible.');
		});
	});
});

casper.then(function() {

	casper.test.info("Reload the page:");

	this.reload(function() {

		this.test.assertEquals(this.getElementAttribute('#' + sprintId + ' input[name="title"]', 'value'), 'New Sprint 1', 'Sprint title changes are kept.');
		this.test.assertEquals(this.getHTML('#' + sprintId + ' textarea[name="description"]'), '1 Sprint description', 'Sprint description changes are kept.');
	});
});

// Open Sprint

casper.then(function() {

	casper.test.info("Double-click on the header of test sprint:");

	this.mouseEvent('click', '#' + sprintId + ' .header');

	sprintUrl = 'http://localhost:8000/sprint/' + sprintId.substr('uuid-'.length);

	casper.waitForResource(sprintUrl, function() {

		this.test.assertDoesntExist('#panel-container .panel', 'No story visible.');
	});
});

casper.then(function() {

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

	this.mouseEvent('click', '#' + story1Id + ' .header');

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

	this.mouseEvent('click', '#' + task2Id + ' .header');

	task2Url = 'http://localhost:8000/task/' + task2Id.substr('uuid-'.length);

	casper.waitForResource(task2Url, function() {

		this.test.assertEquals(this.getElementAttribute('#' + task2Id + ' input[name="summary"]', 'value'), 'New Task 2', 'Task summary is correct.');
		this.test.assertEquals(this.getHTML('#' + task2Id + ' textarea[name="description"]'), 'Description of task 2.', 'Task description is correct.');
		this.test.assertEquals(this.getHTML('#story-selector .selected'), 'New Story 1', 'Story assignment is correct.');

		this.test.assert(this.getElementAttribute('#color-selector .selected', 'class').split(' ').indexOf('blue') != -1, 'Color is set to blue.');
	});
});

casper.then(function() {

	this.test.info("Click on color selector:");

	this.click('#color-selector .selected');
	this.test.assertVisible('#color-selector .content', 'Color dialog appeared.');

	this.test.info("Click on purple box:");
	this.click('#color-selector .purple');

	casper.waitForResource(task2Url, function() {

		this.test.assert(this.getElementAttribute('#color-selector .selected', 'class').split(' ').indexOf('purple') != -1, 'Color is set to purple.');
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

	this.mouseEvent('click', '#' + story2Id + ' .header');

	story2Url = 'http://localhost:8000/story/' + story2Id.substr('uuid-'.length);

	casper.waitForResource(story2Url, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 1;
		}, '1 task panel is visible.');
		this.test.assert(this.getElementAttribute('#' + task2Id + ' .stripe', 'class').split(' ').indexOf('purple') != -1, 'Color of task 2 is purple.');
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

		this.test.assert(this.getElementAttribute('#color-selector .selected', 'class').split(' ').indexOf('red') != -1, 'Color is set to red.');
	});
});

casper.then(function() {

	var startDay = this.fetchText('#start-selector span.selected').split('/')[1];
	var startMonth = this.fetchText('#start-selector span.selected').split('/')[0];
	var startYear = this.fetchText('#start-selector span.selected').split('/')[2];

	this.test.info("Click on start date:");

	this.click('#start-selector .selected');

  this.test.assertVisible('#start-selector .content', 'Datepicker popup appeared.');

  var newStartDay = '2';
  if (startDay == '2') {

		newStartDay = '3';
  }

	this.test.info('Click on day ' + newStartDay + ':');

	var row = 1;
	var column = 1;
	while(true) {

		var day = this.fetchText('#start-selector .content tr:nth-of-type(' + row + ') td:nth-of-type(' + column + ') a');
		if (day == newStartDay) {

			break;
		}
		if (column == 7) {

			column = 0;
			row++;
		}
		column++;
	}

	this.click('#start-selector .content tr:nth-of-type(' + row + ') td:nth-child(' + column + ')');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('#start-selector .content', 'Datepicker popup disappeared.');
		var newStartDate = startMonth + '/' + newStartDay + '/' + startYear;
		var newEndDate = startMonth + '/' + (parseInt(newStartDay, 10) + 14) + '/' + startYear;
		this.test.assertSelectorHasText('#start-selector span.selected', newStartDate, 'Start date is set to ' + newStartDate + '.');
		this.test.assertSelectorHasText('#length-selector span.selected', newEndDate, 'End date has been moved to ' + newEndDate + '.');
	});
});

casper.then(function() {

	var endDay = this.fetchText('#length-selector span.selected').split('/')[1];
	var endMonth = this.fetchText('#length-selector span.selected').split('/')[0];
	var endYear = this.fetchText('#length-selector span.selected').split('/')[2];

	this.test.info("Click on end date:");

	this.click('#length-selector .selected');

  this.test.assertVisible('#length-selector .content', 'Datepicker popup appeared.');

	this.test.info("Click on day 1 (illegal b/c before start date):");

	var column = 1;
	while(true) {

		var day = this.evaluate(function(column) {

			return $('#length-selector .content tbody tr:first td:nth-of-type(' + column + ')').text();
		}, column);
		if (day == '1') {

			break;
		}
		column++;
	}

	this.click('#length-selector .content tr:nth-of-type(1) td:nth-child(' + column + ')');

  this.test.assertVisible('#length-selector .content', 'Datepicker popup did not disappear.');

	this.test.info("Click on day 10:");

	var row = 1;
	column = 1;
	while(true) {

		var day = this.fetchText('#length-selector .content tr:nth-of-type(' + row + ') td:nth-of-type(' + column + ')');
		if (day == '10') {

			break;
		}
		if (column == 7) {

			column = 0;
			row++;
		}
		column++;
	}

	this.click('#length-selector .content tr:nth-of-type(' + row + ') td:nth-child(' + column + ')');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('#length-selector .content', 'Datepicker popup disappeared.');
		var newEndDate = endMonth + '/10/' + endYear;
		this.test.assertSelectorHasText('#length-selector span.selected', newEndDate, 'End date is set to ' + newEndDate + '.');
	});
});

// Cleanup

casper.then(function() {

  casper.test.info('Go back:');

  this.back();

	casper.waitForResource(indexUrl, function() {

		this.test.assertVisible('#logo-panel', 'Logo panel visible.');	
	});
});

casper.then(function() {

  casper.test.info("Click the remove button on test sprint:");

  this.click('#' + sprintId + ' .remove.button');
  
  this.waitForResource(indexUrl, function() {

		this.test.assertDoesntExist('#' + sprintId, 'Panel for test sprint disappeared.');
		var newSprintIds = this.evaluate(buildIdList);
		this.test.assertEquals(newSprintIds.length, sprintIds.length, 'There are ' + sprintIds.length + ' sprints visible.');
	});
});

casper.run(function() {

	this.test.done(69);
	this.test.renderResults(true);
});