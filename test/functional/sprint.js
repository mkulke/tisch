var http = require('http');
var Browser = require('zombie');
var assert = require('assert');
var app = require('../../server')

// temp
var sprintId = '519a854a71516f7afce4a63d';
var storyId;

process.env.NODE_ENV = 'test';

describe('sprint view', function() {

  before(function() {
  
    this.server = http.createServer(app).listen(3000);
    this.browser = new Browser({site: 'http://localhost:3000'});
  });
  
  beforeEach(function(done) {
  
    this.browser.visit('/sprint/' + sprintId, done);
  });
  
  it('show sprint details', function() {
    
    assert.ok(this.browser.success);
    assert.ok(this.browser.query('.main-panel .header input[value="test sprint"]'));
    assert.equal(this.browser.text('.main-panel .description textarea'), "test description");
  });
  it('create a new story', function(done) {
  
    var browser = this.browser;
    browser.fire('#add-button', 'click').then(function() {
    
      assert.equal(browser.queryAll('#panel-container .panel').length, 1);
      storyId = browser.query('#panel-container .panel').getAttribute('id');
      assert.ok(storyId);
    }).then(done, done);
  });
  it('edit a story', function(done) {
  
    var testTitle = 'test title';
    var testDescription = 'test description';
  
    var browser = this.browser;
    browser.fill('#' + storyId + ' .header input', testTitle);
    browser.fill('#' + storyId + ' .description textarea', testDescription);
    browser.fire('#' + storyId + ' .save-button', 'click').then(function() {

      browser.reload(function() {
      
        assert.equal(browser.query('#' + storyId + ' .header input').getAttribute('value'), testTitle);
        assert.equal(browser.text('#' + storyId + ' .description textarea'), testDescription);
      }).then(done, done);
    });      
  });
  it('remove a story', function(done) {
  
    var browser = this.browser;
    browser.onconfirm('Do you want to remove the item and its assigned objects?', true);
  
    browser.fire('#' + storyId + ' .remove-button', 'click').then(function() {

      browser.reload(function() {
      
        assert.equal(browser.query('#' + storyId, null));
      });
    }).then(done, done);      
  });
  after(function(done) {
  
    this.server.close(done);
  });
})