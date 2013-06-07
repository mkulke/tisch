
var casper = require('casper').create();

var storyId, storyUrl, taskId, taskUrl;

var sprintUrl = 'http://localhost:8000/sprint/51ac972325dfbc3750000001';

casper.start(sprintUrl);

casper.viewport(1024, 768);

casper.then(function() {

	this.test.assertDoesntExist('ul#panel-container .panel', 'No story visible.');

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.then(function() {

	casper.waitForResource(sprintUrl);
});

casper.then(function() {

	this.test.assertVisible('ul#panel-container li:nth-child(1)', 'New story appeared.');
	storyId = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');
	storyUrl = 'http://localhost:8000/story/' + storyId.substr('uuid-'.length);

	casper.test.info("Doubleclick on the header of the story");

	this.mouseEvent('dblclick', '#' + storyId + ' .handle');
});

casper.then(function() {

	casper.waitForResource(storyUrl);
});

casper.then(function() {

	this.test.assertDoesntExist('ul#panel-container .panel', 'No task visible.');

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl);
});

casper.then(function() {

	this.test.assertVisible('ul#panel-container li:nth-child(1)', 'New task appeared.');
	firstId = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');
});

casper.then(function() {

	taskId = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');
	taskUrl = 'http://localhost:8000/task/' + taskId.substr('uuid-'.length);

	casper.test.info("Doubleclick on the header of the task");

	this.mouseEvent('dblclick', '#' + taskId + ' .handle');
});

// actual task tests

casper.then(function() {

	casper.waitForResource(taskUrl, function () {

		this.test.assertNotVisible('#' + taskId + ' .save-button', "Save button not visible.");

		casper.test.info("Edit summary and description:");

		this.sendKeys('#' + taskId + ' .header input[name="summary"]', 'Test summary');
		this.test.assertVisible('#' + taskId + ' .save-button', "Save button on task is visible.");
		this.sendKeys('#' + taskId + ' .description textarea', 'Test description');

		casper.test.info("Click save button and reload:");
		this.click('#' + taskId + ' .save-button');
	});
});

casper.then(function() {

	casper.waitForResource(taskUrl);
});

casper.then(function() {

	casper.reload(function() {

		var summary = this.getElementAttribute('#' + taskId + ' input[name="summary"]', 'value');
		var description = this.getHTML('#' + taskId + ' textarea[name="description"]');
		this.test.assert((summary == 'Test summary') && (description == 'Test description'), 'Task attributes are correct.');

		casper.test.info('Put "abc" into "Initial Estimation" field & click save button:')

		this.sendKeys('#' + taskId + ' input[name="initial_estimation"]', 'abc');
		this.click('#' + taskId + ' .save-button');
		this.test.assertVisible('#error-panel', 'The error panel appears.');
	});
});

// cleanup

casper.then(function() {

	casper.test.info("Go to sprint view and click remove on story:")

	casper.open(sprintUrl);
});

casper.then(function() {

	this.click('#' + storyId + ' .remove-button');
});

casper.then(function() {
	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('ul#panel-container li', 'No story remaining.');
	});
});

casper.run(function() {

	this.test.done(9);
  this.test.renderResults(true);
});