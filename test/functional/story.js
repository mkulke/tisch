var casper = require('casper').create();

var storyId, firstId, secondId, storyUrl;

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

	casper.test.info("Doubleclick on the header of the story");

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

	this.capture('fail.png')

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

	casper.test.info("Doubleclick on the header & go back:");

	this.mouseEvent('dblclick', '#' + secondId + ' .handle');
});

casper.then(function() {

	casper.waitForResource('http://localhost:8000/task/' + secondId.substr('uuid-'.length), function () {

		casper.capture('test.png');
	});
});

casper.then(function() {

	var summary = this.getElementAttribute('#' + secondId + ' input[name="summary"]', 'value');
	var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
	this.test.assert((summary == "New Task II") && (description == "Test description"), "Task attributes are correct."); 
	
	casper.back();
});


casper.then(function() {

	casper.test.info("Click remove button on 2nd task:");

	this.click('#' + secondId + ' .remove-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl, function() {

		this.test.assertNotVisible('#' + secondId, '2nd task disappeared.');

		casper.test.info("Go back and click remove button on story:");

		casper.back();
	});
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

	this.test.done(15);
  this.test.renderResults(true);
});