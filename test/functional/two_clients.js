
var casper1 = require('casper').create();
var casper2 = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

var sprintUrl = 'http://localhost:8000/sprint/51ac972325dfbc3750000001';
var story1Id, story2Id, story1Url, story2Url, task1Id, task2Id;

casper1.test.info("Open the sprint test page on 2 clients.");

casper1.start(sprintUrl);
casper1.viewport(1024, 768);

casper2.start(sprintUrl);
casper2.viewport(1024, 768);

function makePrefix(i) {

	return function(text) {

		return 'Client ' + i + ': ' + text;		
	};
}

function makeWaitForOtherClient(i) {

	var j = ((i - 1) ^ 1) + 1;
	var otherClient = clients[j];

	return function() {

		this.waitFor(function() {

			return otherClient.isDone;
		}, function() {

			otherClient.isDone = false;
		});
	};
}

function makeDone(i) {

	return function() {

		clients[i].isDone = true;
	};
}

var clients = {1: casper1, 2: casper2};

for (var i in clients) {

	var client = clients[i];
	client.prefix = makePrefix(i);
	client.isDone = false;
	client.done = makeDone(i);
	client.waitForOtherClient = makeWaitForOtherClient(i);
}

// Create

casper1.then(function() {

	this.test.assertDoesntExist('#panel-container .panel', this.prefix('No story visible.'));

  this.test.info(this.prefix("Click the add button twice."));

	this.click('#add-button');
	this.click('#add-button');

	this.waitForResource(sprintUrl, function() {

		this.done();
	});
});

casper2.then(function() {

	this.waitForOtherClient();
});

// Edit

casper2.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length == 2;
	}, this.prefix('2 story panels are visible.'));

	story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
	story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

  this.test.info(this.prefix('Edit title & description of story 1 (and wait 2s).'));

  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');
	this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');

	this.wait(2000);
});

casper2.then(function() {

	this.waitForResource(sprintUrl, function() {

		this.done();
	});
});

casper1.then(function() {

	this.waitForOtherClient();
});

// Open and change color.

casper1.then(function() {

	this.test.assertEval(function(id) {

		return document.querySelector('#' + id + ' input[name="title"]').value == 'New Story 1';
	}, this.prefix('Story title changes have been updated.'), story1Id);

	this.test.assertEval(function(id) {

		return document.querySelector('#' + id + ' textarea[name="description"]').value == 'Description of story 1.';
	}, this.prefix('Story description changes have been updated.'), story1Id);

	this.test.info(this.prefix('Double-click on the header of story 1.'));

	this.mouseEvent('dblclick', '#' + story1Id + ' .handle');

	story1Url = 'http://localhost:8000/story/' + story1Id.substr('uuid-'.length);

	this.waitForResource(story1Url);
});

casper1.then(function() {

	this.test.info(this.prefix("Select purple as the story's color."));

	this.click('#color-selector .selected');
	this.click('#color-selector .purple');

	this.waitForResource(story1Url, function() {

		this.done();
	});
});

casper2.then(function() {

	this.waitForOtherClient();
});

// Go back.

casper1.then(function() {

	this.test.info(this.prefix('Go back to sprint view.'));

	this.back();
});

casper1.then(function() {

	this.done();
});

casper2.then(function() {

	this.test.assert(this.getElementAttribute('#' + story1Id + ' .header', 'class').split(' ').indexOf('purple') != -1, this.prefix('Header color is set to purple.'));

	this.waitForOtherClient();
});

// Change priority

casper1.then(function() {

	this.test.info(this.prefix('Move story 2 to position 1.'));

	var info1 = this.getElementInfo('#' + story1Id +' .handle');
	var info2 = this.getElementInfo('#' + story2Id +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.waitForResource(sprintUrl, function() {

		this.done();
	});
});

casper2.then(function() {

	this.waitForOtherClient();
});

// Remove

casper2.then(function() {

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), this.prefix('Story 2 is on position 1.'));

	this.test.info(this.prefix('Click the remove button story 1 and story 2.'));

	this.click('#' + story1Id + ' .remove-button');
	this.click('#' + story2Id + ' .remove-button');

	this.waitForResource(sprintUrl, function() {

		this.done();
	});
});

casper1.then(function() {

	this.waitForOtherClient();
});

// Aftermath

casper1.then(function() {

	this.test.info(this.prefix('Go back to sprint view.'));

	this.back();
});

casper1.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length === 0;
	}, this.prefix('No story panel is visible.'));

	this.done();
});

casper2.then(function() {

	this.waitForOtherClient();
});

casper1.run();
casper2.run();
