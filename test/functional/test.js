
var casper = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

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
});

casper.then(function() {

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.then(function() {

	casper.waitForResource(sprintUrl, function () {

		this.test.assertVisible('ul#panel-container li:nth-child(2)', '2nd story appeared.');
		secondId = this.getElementAttribute('ul#panel-container li:nth-child(2)', 'id');
	});
});

casper.then(function() {

	casper.test.info("Modify 2nd story's attributes:");

	this.test.assertNotVisible('#' + secondId + ' .save-button', "No save button on 2nd story.");
	this.sendKeys('#' + secondId + ' .header input', ' II');
	this.test.assertVisible('#' + secondId + ' .save-button', "Save button on 2nd story is visible.");
	this.sendKeys('#' + secondId + ' .description textarea', 'Test description');
});

casper.then(function() {

	casper.test.info("Save modifications on 2nd story and reload:");

	this.click('#' + secondId + ' .save-button', function() {

		casper.waitForResource(sprintUrl);
	});
});

casper.then(function() {

	this.test.assertNotVisible('#' + secondId + ' .save-button', "No save button on 2nd story.");

	casper.reload(function() {

		var title = this.getElementAttribute('#' + secondId + ' input[name="title"]', 'value');
		var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
		this.test.assert((title == "New Story II") && (description == "Test description"), "Story attributes are kept after reload."); 
	});
});

casper.then(function() {

	casper.test.info("Move 2nd story to 1st position:");

	var info1 = this.getElementInfo('#' + storyId +' .handle');
	var info2 = this.getElementInfo('#' + secondId +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd story is on 1st position now.');
});

casper.then(function() {

	casper.test.info("Save 2nd story and reload:");

	this.test.assertVisible('#' + secondId + ' .save-button', "Save button on 2nd story is visible.");
	this.click('#' + secondId + ' .save-button', function() {

		casper.waitForResource(sprintUrl);
	});
});

casper.then(function () {

	this.reload(function() {

		this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd story is still on 1st position.');
	});
});

casper.then(function() {

	casper.test.info("Doubleclick on the header & go back:");

	this.mouseEvent('dblclick', '#' + secondId + ' .handle');

	casper.waitForResource('http://localhost:8000/story/' + secondId.substr('uuid-'.length));
});

casper.then(function() {

	var title = this.getElementAttribute('#' + secondId + ' input[name="title"]', 'value');
	var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
	this.test.assert((title == "New Story II") && (description == "Test description"), "Story attributes are correct."); 
	this.test.assertDoesntExist('ul#panel-container .panel', 'No task visible.');
	
	casper.back();
});

casper.then(function() {

	casper.test.info("Doubleclick on the header of the 1st story:");

	this.mouseEvent('dblclick', '#' + storyId + ' .handle');
});

casper.then(function() {

	casper.waitForResource(sprintUrl, function () {

		casper.capture('test.png');
	});
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

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl, function () {

		this.test.assertVisible('ul#panel-container li:nth-child(2)', '2nd task appeared.');
		secondId = this.getElementAttribute('ul#panel-container li:nth-child(2)', 'id');
	});
});

casper.then(function() {

	casper.test.info("Modify 2nd task's attributes:");

	this.test.assertNotVisible('#' + secondId + ' .save-button', "No save button on 2nd task.");
	this.sendKeys('#' + secondId + ' .header input', ' II');
	this.test.assertVisible('#' + secondId + ' .save-button', "Save button on 2nd task is visible.");
	this.sendKeys('#' + secondId + ' .description textarea', 'Test description');
});

casper.then(function() {

	casper.test.info("Save modifications on 2nd task and reload:");

	this.click('#' + secondId + ' .save-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl);
});

casper.then(function() {

	this.test.assertNotVisible('#' + secondId + ' .save-button', "No save button on 2nd task.");

	casper.reload(function() {

		var summary = this.getElementAttribute('#' + secondId + ' input[name="summary"]', 'value');
		var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
		this.test.assert((summary == "New Task II") && (description == "Test description"), "Task attributes are kept after reload."); 
	});
});

casper.then(function() {

	casper.test.info("Move 2nd task to 1st position:");

	var info1 = this.getElementInfo('#' + firstId +' .handle');
	var info2 = this.getElementInfo('#' + secondId +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd task is on 1st position now.');
});

casper.then(function() {

	casper.test.info("Save 2nd task and reload:");

	this.test.assertVisible('#' + secondId + ' .save-button', "Save button on 2nd task is visible.");
	this.click('#' + secondId + ' .save-button', function() {

		casper.waitForResource(storyUrl);
	});
});

casper.then(function () {

	this.reload(function() {

		this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd task is still on 1st position.');
	});
});

casper.then(function() {

	casper.test.info("Doubleclick on the header:");

	this.mouseEvent('dblclick', '#' + secondId + ' .handle');
});

casper.then(function() {

	secondUrl = 'http://localhost:8000/task/' + secondId.substr('uuid-'.length);

	casper.waitForResource(secondUrl, function () {

		casper.capture('test.png');
	});
});

casper.then(function() {

	var summary = this.getElementAttribute('#' + secondId + ' input[name="summary"]', 'value');
	var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
	this.test.assertEquals(summary, "New Task II", 'Summary is correct.');
	this.test.assertEquals(description, "Test description", 'Description is correct.');
});

// actual task tests

casper.then(function() {

	casper.waitForResource(secondUrl, function () {

		this.test.assertNotVisible('#' + secondId + ' .save-button', "Save button not visible.");

		casper.test.info("Edit summary and description:");

		this.sendKeys('#' + secondId + ' .header input[name="summary"]', 'Test summary');
		this.test.assertVisible('#' + secondId + ' .save-button', "Save button on task is visible.");
		this.sendKeys('#' + secondId + ' .description textarea', 'New ');

		casper.test.info("Click save button and reload:");
		this.click('#' + secondId + ' .save-button');
	});
});

casper.then(function() {

	casper.waitForResource(secondUrl);
});

casper.then(function() {

	casper.reload(function() {

		var summary = this.getElementAttribute('#' + secondId + ' input[name="summary"]', 'value');
		var description = this.getHTML('#' + secondId + ' textarea[name="description"]');

		this.test.assertEquals(summary, "Test summary", 'Summary is correct.');
		this.test.assertEquals(description, "New Test description", 'Description is correct.');

		//this.test.assert((summary == 'Test summary') && (description == 'Test description'), 'Task attributes are correct.');

		casper.test.info('Put "abc" into "Initial Estimation" field & click save button:');

		this.sendKeys('#' + secondId + ' input[name="initial_estimation"]', 'abc');
		this.click('#' + secondId + ' .save-button');
		this.test.assertVisible('#error-panel', 'The error panel appears.');

		casper.back();
	});
});

// cleanup

casper.then(function() {

	casper.test.info("Click remove button on 2nd task:");

	this.click('#' + secondId + ' .remove-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl, function() {

		this.test.assertNotVisible('#' + secondId, '2nd task disappeared.');

		casper.test.info("Go back and click remove button on storie:");

		casper.back();
	});
});

casper.then(function() {

	this.click('ul#panel-container li:nth-child(2) .remove-button');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('ul#panel-container li:nth-child(2)', 'Story not visible anymore.');	
	});
});

casper.then(function() {

	casper.test.info("Click remove button on 2nd story:");

	this.click('ul#panel-container li:nth-child(1) .remove-button');

	casper.waitForResource(sprintUrl, function() {

		this.test.assertNotVisible('ul#panel-container li', 'No story remaining.');	
	});
});

casper.run(function() {

	this.test.done(32);
  this.test.renderResults(true);
});