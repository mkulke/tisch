var casper = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

var indexUrl = 'http://localhost:8000/';
//var sprintUrl = indexUrl + 'sprint/51ac972325dfbc3750000001';
var sprintId, sprintUrl;

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

// Remove

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

	this.test.done(8);
	this.test.renderResults(true);
});