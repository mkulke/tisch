var casper = require('casper').create();

var firstId, secondId;

var url = 'http://localhost:8000/sprint/51ac972325dfbc3750000001';

casper.start(url);

casper.viewport(1024, 768);

casper.then(function() {

	this.test.assertDoesntExist('ul#panel-container .panel', 'No story visible.');

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.waitForResource(url);

casper.then(function() {

	this.test.assertVisible('ul#panel-container li:nth-child(1)', 'New story appeared.');
	firstId = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');
});

// 2nd item created

casper.then(function() {

	casper.test.info("Click the add button:");

	this.click('#add-button');
});

casper.waitForResource(url, function () {

	this.test.assertVisible('ul#panel-container li:nth-child(2)', '2nd story appeared.');
	secondId = this.getElementAttribute('ul#panel-container li:nth-child(2)', 'id');
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

	this.click('#' + secondId + ' .save-button');
})

casper.waitForResource(url, function () {

	this.test.assertNotVisible('#' + secondId + ' .save-button', "No save button on 2nd story.");
});

casper.then(function() {

	casper.reload(function() {

		var title = this.getElementAttribute('#' + secondId + ' input[name="title"]', 'value');
		var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
		this.test.assert((title == "New Story II") && (description == "Test description"), "Story attributes are kept after reload."); 
	});
})

casper.then(function() {

	casper.test.info("Move 2nd story to 1st position:");

	var info1 = this.getElementInfo('#' + firstId +' .handle');
	var info2 = this.getElementInfo('#' + secondId +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd story is on 1st position now.');
});

casper.then(function() {

	casper.test.info("Save 2nd story and reload:");

	this.test.assertVisible('#' + secondId + ' .save-button', "Save button on 2nd story is visible.");
	this.click('#' + secondId + ' .save-button');
});

casper.waitForResource(url, function () {

	this.reload(function() {

		this.test.assertEquals(secondId, this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id'), '2nd story is still on 1st position.');
	});
});

casper.then(function() {

	casper.test.info("Click remove button on 2nd story:");

	this.click('#' + secondId + ' .remove-button');
})

casper.waitForResource(url, function() {

	this.test.assertNotVisible('#' + secondId, '2nd story disappeared.');
});

casper.then(function() {

	casper.test.info("Click remove button on remaining story:");

	this.click('#' + firstId + ' .remove-button');
})

casper.waitForResource(url, function() {

	this.test.assertNotVisible('ul#panel-container li', 'No story remaining.');
});

casper.run(function() {

	this.test.done(12);
  this.test.renderResults(true);
});