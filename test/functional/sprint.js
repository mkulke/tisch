var casper = require('casper').create();

var id;

var url = 'http://localhost:8000/sprint/51ac972325dfbc3750000001';

casper.start(url);

casper.then(function() {

	this.click('#add-button');
});

casper.waitForResource(url);

casper.then(function() {

	this.test.assertVisible('ul#panel-container li:nth-child(1)', 'New story panel appeared.');
	id = this.getElementAttribute('ul#panel-container li:nth-child(1)', 'id');
});

casper.then(function() {

	this.click('#' + id + ' .remove-button');
})

casper.waitForResource(url);

casper.then(function() {

	this.test.assertNotVisible('#' + id, 'Story panel disappeared.');
});

casper.run(function() {

	this.test.done(2);
  this.test.renderResults(true);
});