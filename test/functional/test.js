
var casper = require('casper').create();

var storyId, firstId, secondId, secondUrl, storyUrl;

var sprintUrl = 'http://localhost:8000/sprint/51ac972325dfbc3750000001';
var story1Id, story2Id, story1Url, task1Id, task2Id;

casper.test.info("Open the sprint test page:");

casper.start(sprintUrl);

casper.viewport(1024, 768);

casper.then(function() {

	this.test.assertDoesntExist('#panel-container .panel', 'No story visible.');

	casper.test.info("Click the add button 2 times:");

	this.click('#add-button');
	this.click('#add-button');
	this.waitForResource(sprintUrl);
});

casper.then(function() {

  this.test.assertEval(function() {

    return document.querySelectorAll('#panel-container .panel').length == 2;
  }, '2 story panels are visible.');

  story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
	story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

  casper.test.info("Edit title & description of story 1 (and wait 2s):");

  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');
	this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');

	this.wait(2000, function () {

		this.waitForResource(sprintUrl);
	});
});

casper.then(function() {

	this.test.assertNotVisible('#error-panel', 'Error panel is not visible.');

	casper.test.info("Reload the page:");

	this.reload();
});

casper.then(function() {

	this.test.assertEquals(this.getElementAttribute('#' + story1Id + ' input[name="title"]', 'value'), 'New Story 1', 'Story title changes are kept.');
	this.test.assertEquals(this.getHTML('#' + story1Id + ' textarea[name="description"]'), 'Description of story 1.', 'Story description changes are kept.');

	casper.test.info("Move story 2 to position 1:");

	var info1 = this.getElementInfo('#' + story1Id +' .handle');
	var info2 = this.getElementInfo('#' + story2Id +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is on position 1.');

	casper.test.info("Reload page:");

	this.reload();
});

casper.then(function() {

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is still on position 1.');

	casper.test.info("Double-click on the header of story 1:");

	this.mouseEvent('dblclick', '#' + story1Id + ' .handle');

	story1Url = 'http://localhost:8000/story/' + story1Id.substr('uuid-'.length);

	casper.waitForResource(story1Url);
});

casper.then(function() {

	this.test.assertEquals(this.getElementAttribute('#' + story1Id + ' input[name="title"]', 'value'), 'New Story 1', 'Story title is correct.');
	this.test.assertEquals(this.getHTML('#' + story1Id + ' textarea[name="description"]'), 'Description of story 1.', 'Story description is correct.');
  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 0;
  }, 'No panels are visible.');

  this.test.info('Click the add button 3 times.')

	this.click('#add-button');
	this.click('#add-button');
	this.click('#add-button');

	this.waitForResource(story1Url);
});

casper.then(function() {

  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 3;
  }, '3 task panels are visible.');

  task1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
  task2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

  casper.test.info("Edit title & description of task 2 (and wait 2s):");

  this.sendKeys('#' + task2Id + ' input[name="summary"]', ' 2');
	this.sendKeys('#' + task2Id + ' textarea[name="description"]', 'Description of task 2.');

	this.wait(2000, function () {

		this.waitForResource(story1Url);
	});
});

casper.then(function() {

	this.test.assertNotVisible('#error-panel', 'Error panel is not visible.');

	casper.test.info("Reload the page:");

	this.reload();
});

casper.then(function() {

	this.test.assertEquals(this.getElementAttribute('#' + task2Id + ' input[name="summary"]', 'value'), 'New Task 2', 'Task summary changes are kept.');
	this.test.assertEquals(this.getHTML('#' + task2Id + ' textarea[name="description"]'), 'Description of task 2.', 'Task description changes are kept.');

	casper.test.info("Move task 1 to position 2:");

	var info1 = this.getElementInfo('#' + task1Id +' .handle');
	var info2 = this.getElementInfo('#' + task2Id +' .handle');

	this.mouse.down(info1.x + info1.width / 2, info1.y);
	this.mouse.move(info2.x + info2.width / 2, info2.y);
	this.mouse.up(info2.x + info2.width / 2, info2.y);

	this.test.assertEquals(task1Id, this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id'), 'Task 1 is on position 2.');

	casper.test.info("Reload page:");

	this.reload();
});

casper.then(function() {

	this.test.assertEquals(task1Id, this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id'), 'Task 1 is still on position 2.');

  casper.test.info("Click the remove button on task 1:");

  this.click('#' + task1Id + ' .remove-button');
  this.waitForResource(story1Url);
});

casper.then(function() {

  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 2;
  }, '2 task panels are visible.');

	casper.test.info("Double-click on the header of task 2:");

	this.mouseEvent('dblclick', '#' + task2Id + ' .handle');

	task2Url = 'http://localhost:8000/task/' + task2Id.substr('uuid-'.length);

	casper.waitForResource(task2Url);
});

casper.then(function() {

	this.test.assertEquals(this.getElementAttribute('#' + task2Id + ' input[name="summary"]', 'value'), 'New Task 2', 'Task summary is correct.');
	this.test.assertEquals(this.getHTML('#' + task2Id + ' textarea[name="description"]'), 'Description of task 2.', 'Task description is correct.');
	this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('blue') != -1, 'Header color is set to blue.');

	this.test.info("Click on color selector:");

	this.click('#color-selector .selected');
	this.test.assertVisible('#color-selector .content', 'Color dialog appeared.');

	this.test.info("Click on purple box:");
	this.click('#color-selector .purple');

	casper.waitForResource(task2Url);
});

casper.then(function(){

	this.test.assert(this.getElementAttribute('.main-panel .header', 'class').split(' ').indexOf('purple') != -1, 'Header color is set to purple.');

	this.test.info('Add an illegal character into the "Initial Estimation" field (and wait 1.5s):');

	this.sendKeys('.main-panel input[name="initial_estimation"]', 'a');

	this.wait(1500, function() {

		casper.capture('test.png');

		this.test.assertVisible('.error-popup .content', 'Error popup appeared.');

  	casper.test.info('Go back:');

  	this.back();
	});
});

casper.then(function() {

	this.test.assert(this.getElementAttribute('#' + task2Id + ' .header', 'class').split(' ').indexOf('purple') != -1, 'Header color of task 2 is purple.');
  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 2;
  }, '2 task panels are visible.');

  casper.test.info('Go back:');

  this.back();
});

casper.then(function() {

  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 2;
  }, '2 story panels are visible.');

  casper.test.info("Click the remove button on story 1:");

  this.click('#' + story1Id + ' .remove-button');
  this.waitForResource(sprintUrl);
});

casper.then(function() {

  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length == 1;
  }, '1 story panel is visible.');

  casper.test.info("Click the remove button on story 2:");

  this.click('#' + story2Id + ' .remove-button');
  this.waitForResource(sprintUrl);
});

casper.then(function() {

  this.test.assertEval(function() {

  	return document.querySelectorAll('#panel-container .panel').length === 0;
  }, 'No story panel is visible.');
});

/*casper.then(function() {

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

	casper.waitForResource(storyUrl, function () {

		this.test.assertDoesntExist('ul#panel-container .panel', 'No task visible.');

		casper.test.info("Click the add button:");

		this.click('#add-button');
	});
});

casper.then(function() {

	casper.waitForResource(storyUrl, function() {

		this.test.assertVisible('ul#panel-container li:nth-child(1)', 'New task appeared.');
		firstId = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');

		casper.test.info("Click the add button:");

		this.click('#add-button');
	});
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

		var summary = this.getElementAttribute('#' + secondId + ' input[name="summary"]', 'value');
		var description = this.getHTML('#' + secondId + ' textarea[name="description"]');
		this.test.assertEquals(summary, "New Task II", 'Summary is correct.');
		this.test.assertEquals(description, "Test description", 'Description is correct.');

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
	});
});

casper.then(function() {

	this.test.info("Click on story selector:");

	this.clickLabel("New Story");
});

casper.then(function() {

	casper.waitForResource(secondUrl, function() {

    this.test.assertEval(function() {

        return document.querySelectorAll('#story-selector .content div').length == 2;
    }, 'Selector has 2 lines.');

		this.test.assertSelectorHasText('#story-selector .content div:nth-child(1)', 'New Story', "Line 1 in selector is correct.");
		this.test.assertSelectorHasText('#story-selector .content div:nth-child(2)', 'New Story II', 'Line 2 in selector is correct.');	

		this.test.info('Click line 2 in selector:')
		this.click('#story-selector .content div:nth-child(2)');
	});
});

casper.then(function() {

	casper.waitForResource(secondUrl, function() {

		this.test.assertSelectorHasText('#story-selector .open span', 'New Story II', "Story label is correct.");
		this.test.assertVisible('#' + secondId + ' .save-button', "Save button is visible.");

		this.test.info('Click the save button:')
		this.click('#' + secondId + ' .save-button');
	});
});

casper.then(function() {

	casper.waitForResource(secondUrl, function() {

		this.test.assertNotVisible('#' + secondId + ' .save-button', "Save button disappeared.");	
	});
});

casper.then(function() {

	this.test.info("Click on color selector:");

	this.click('#color-selector .selected');
	this.test.assertVisible('#color-selector .content', 'Color dialog appeared.');

	this.test.info("Click on purple box:");
	this.click('#color-selector .purple');

	this.test.assertEquals(this.getElementAttribute('.main-panel .header', 'class'), 'header purple', 'Header color is set to purple.');
	this.test.assertEquals(this.getElementAttribute('.main-panel .header input', 'class'), 'purple', 'Input color is set to purple.');
  this.test.assertVisible('#' + secondId + ' .save-button', "Save button appeared.");	

  this.test.info("Click on save button:")

	this.click('#' + secondId + ' .save-button');
});

casper.then(function() {

	casper.waitForResource(secondUrl, function() {

		this.test.assertNotVisible('#' + secondId + ' .save-button', "Save button disappeared.");

		casper.test.info("Reload the page:");

		this.reload(function() {

			this.test.assertEquals(this.getElementAttribute('.main-panel .header', 'class'), 'header purple', 'Header color is kept.');
			this.test.assertEquals(this.getElementAttribute('.main-panel .header input', 'class'), 'purple', 'Input color is kept.');
		});	
	});
});

casper.then(function() {

	casper.test.info('Put "abc" into "Initial Estimation" field & click save button:');

	this.sendKeys('#' + secondId + ' input[name="initial_estimation"]', 'abc');
	this.click('#' + secondId + ' .save-button');
	this.test.assertVisible('#error-panel', 'The error panel appeared.');

	this.test.info('Click ok button on error panel:')

	this.click('#error-panel img.ok-button');

	this.waitWhileVisible('#error-panel', function() {

		this.test.pass('Error panel disappeared.');
	}, function() {

		this.test.fail('Error panel disappeared.');
	}, 1000);

});

casper.then(function() {

	casper.test.info("Go back:");

	casper.back();
});

// cleanup

casper.then(function() {

	casper.capture("test3.png");

  this.test.assertEval(function() {

      return document.querySelectorAll('#panel-container .panel').length == 1;
  }, 'Only 1 task panel is visible.');

	casper.test.info('Click remove button on task:')

	this.click('#' + firstId + ' .remove-button');
});

casper.then(function() {

	casper.waitForResource(storyUrl, function() {

		this.test.assertNotVisible('ul#panel-container li', 'No task remaining.');

		casper.test.info("Go back:");

		casper.back();
	});
});

casper.then(function() {

	casper.test.info("Doubleclick on the header:");

	this.mouseEvent('dblclick', 'ul#panel-container li:nth-child(1) .handle');
});

casper.then(function() {

	casper.waitForResource(secondUrl, function() {

		casper.capture("test2.png");

		this.test.assertEquals(this.getElementAttribute('#' + secondId + ' .header', 'class'), 'header purple', 'Header color is purple.');

		casper.back();
	});
});

casper.then(function() {

	this.test.info("Click remove button on story:");
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
});*/

casper.run(function() {

	this.test.done(28);
  this.test.renderResults(true);
});