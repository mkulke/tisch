
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

var done = {1: false, 2: false};

// Create

casper1.then(function() {

	this.test.assertDoesntExist('#panel-container .panel', 'Client 1: No story visible.');

  this.test.info("Client 1: Click the add button twice.");

	this.click('#add-button');
	this.click('#add-button');

	this.waitForResource(sprintUrl, function() {

		done[1] = true;
	});
});

casper2.then(function() {

	this.waitFor(function() {

		return done[1];
	}, function() {

		done[1] = false;
	});
});

// Edit

casper2.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length == 2;
	}, 'Client 2: 2 story panels are visible on client2.');

	story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
	story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');

  this.test.info("Client 2: Edit title & description of story 1 (and wait 2s).");

  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');
	this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');

	this.wait(2000);
});

casper2.then(function() {

	this.waitForResource(sprintUrl, function() {

		done[2] = true;
	});
});

casper1.then(function() {

	this.waitFor(function() {

		return done[2];
	}, function() {

		done[2] = false;
	});
});

// Open and change color.

casper1.then(function() {

	this.test.assertEval(function(id) {

		return document.querySelector('#' + id + ' input[name="title"]').value == 'New Story 1';
	}, 'Client 1: Story title changes have been updated.', story1Id);

	this.test.assertEval(function(id) {

		return document.querySelector('#' + id + ' textarea[name="description"]').value == 'Description of story 1.';
	}, 'Client 1: Story description changes have been updated.', story1Id);

	this.test.info("Client 1: Double-click on the header of story 1.");

	this.mouseEvent('dblclick', '#' + story1Id + ' .handle');

	story1Url = 'http://localhost:8000/story/' + story1Id.substr('uuid-'.length);

	this.waitForResource(story1Url);
});

casper1.then(function() {

	this.test.info("Client 1: Select purple as the story's color.");

	this.click('#color-selector .selected');
	this.click('#color-selector .purple');

	this.waitForResource(story1Url, function() {

		done[1] = true;
	});
});

casper2.then(function() {

	this.waitFor(function() {

		return done[1];
	}, function() {

		done[1] = false;
	});
});

// Go back.

casper1.then(function() {

	this.test.info("Client 1: Go back to sprint view.");

	this.back();
})

casper1.then(function() {

	done[1] = true;
})

casper2.then(function() {

	this.test.assert(this.getElementAttribute('#' + story1Id + ' .header', 'class').split(' ').indexOf('purple') != -1, 'Client 2: Header color is set to purple.');

	this.waitFor(function() {

		return done[1];
	}, function() {

		done[1] = false;
	});
});

// Change priority

casper1.then(function() {

	this.test.info("Client 1: Move story 2 to position 1.");

	var info1 = this.getElementInfo('#' + story1Id +' .handle');
	var info2 = this.getElementInfo('#' + story2Id +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.waitForResource(sprintUrl, function() {

		done[1] = true;
	});
});

casper2.then(function() {

	this.waitFor(function() {

		return done[1];
	}, function() {

		done[1] = false;
	});
});

// Remove

casper2.then(function() {

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Client2: Story 2 is on position 1.');

	this.test.info("Client 2: Click the remove button story 1 and story 2.");

	this.click('#' + story1Id + ' .remove-button');
	this.click('#' + story2Id + ' .remove-button');

	this.waitForResource(sprintUrl, function() {

		done[2] = true;
	});
});

casper1.then(function() {

	this.waitFor(function() {

		return done[2];
	}, function() {

		done[2] = false;
	});
});

// Aftermath

casper1.then(function() {

	this.test.info("Client 1: Go back to sprint view.");

	this.back();
})

casper1.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length === 0;
	}, 'Client 1: No story panel is visible.');

	done[1] = true;
});

casper2.then(function() {

	this.waitFor(function() {

		return done[1];
	}, function() {

		done[1] = false;
	});
});

/*casper2.then(function() {

	this.test.assertDoesntExist('#panel-container .panel', 'No story visible.');

	this.wait(1000);
});

casper.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length == 2;
	}, '2 story panels are visible.');

	story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
	story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');
});

casper2.then(function() {

	this.test.assertEval(function() {

		return document.querySelectorAll('#panel-container .panel').length == 2;
	}, '2 story panels are visible.');
});*/

/*casper.then(function() {

  this.test.info("Edit title & description of story 1 (and wait 2s):");

  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');
	this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');

	this.wait(2000);
});*/

/*  casper2.then(function() {

  	this.wait(3000, function() {

			this.test.assertEval(function() {

				return document.querySelectorAll('#panel-container .panel').length == 2;
			}, '2 story panels appeared on the 2nd client.');

			casper2.capture('bla.png');

			this.test.assertEquals(this.getElementAttribute('#panel-container .panel:nth-child(2) input[name="title"]', 'value'), 'New Story 1', 'Story title changes have been updated.');
			this.test.assertEquals(this.getHTML('#panel-container .panel:nth-child(2) textarea[name="description"]'), 'Description of story 1.', 'Story description changes have been updated.');
  	});
  });

  casper2.then(function() {

  	this.click('#' + story1Id + ' .remove-button');
  	this.click('#' + story2Id + ' .remove-button');

  	this.waitForResource(sprintUrl, function() {

			this.test.assertEval(function() {

				return document.querySelectorAll('#panel-container .panel').length === 0;
			}, 'No story panel is visible.');
		});
	});

  casper2.run(function() {


  });

	this.test.info("Click the add button 2 times:");

	this.click('#add-button');
	this.click('#add-button');
	this.waitForResource(sprintUrl, function() {

		this.test.assertEval(function() {

			return document.querySelectorAll('#panel-container .panel').length == 2;
		}, '2 story panels are visible.');

		story1Id = this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id');
		story2Id = this.getElementAttribute('#panel-container .panel:nth-child(2)', 'id');
	});
});*/


/*casper.then(function() {

  this.test.info("Edit title & description of story 1 (and wait 1.5s):");

  this.sendKeys('#' + story1Id + ' input[name="title"]', ' 1');
	this.sendKeys('#' + story1Id + ' textarea[name="description"]', 'Description of story 1.');

	this.wait(1500, function () {

		this.waitForResource(sprintUrl, function() {

			this.test.assertNotVisible('#error-panel', 'Error panel is not visible.');
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

	var info1 = this.getElementInfo('#' + story1Id +' .handle');
	var info2 = this.getElementInfo('#' + story2Id +' .handle');

	this.mouse.down(info2.x + info2.width / 2, info2.y);
	this.mouse.move(info1.x + info1.width / 2, info1.y);
	this.mouse.up(info1.x + info1.width / 2, info1.y);

	this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is on position 1.');

	casper.test.info("Reload page:");

	this.reload(function() {

		this.test.assertEquals(story2Id, this.getElementAttribute('#panel-container .panel:nth-child(1)', 'id'), 'Story 2 is still on position 1.');
	});
});*/

casper1.run();
casper2.run();
