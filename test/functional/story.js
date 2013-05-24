var http = require('http');
var Browser = require('zombie');
var assert = require('assert');
var app = require('../../server');
var Q = require('q');
var MongoClient = require('mongodb').MongoClient;
var ObjectID = require('mongodb').ObjectID;

var storyData = {

 _rev : 0,
 description: 'initial description',
 estimated_time: 0,
 priority: 1,
 sprint_id: ObjectID(),
 title: 'initial title' 
}

var storyId;
var storyId;
var panels;

process.env.NODE_ENV = 'test';

function clickAddButton() {

  return this.fire('#add-button', 'click');
}

function clickRemoveButton() {

  return this.browser.fire('#' + this.id + ' .remove-button', 'click');
}

function clickSaveButton() {

  return this.browser.fire('#' + this.id + ' .save-button', 'click');
}

function connectToDb() {

  var deferred = Q.defer(); 
  MongoClient.connect("mongodb://localhost:27017/test", function(err, db) {
  
    if (err) {
    
      deferred.reject(new Error(err));
    } else {
    
      deferred.resolve(db);
    } 
  });
  return deferred.promise;
}

function addStoryToDb(db) {

  var deferred = Q.defer(); 
  db.collection("story").insert(storyData, function(err, result) {

    db.close();  
  
    if (err) {
  
      deferred.reject(new Error(err));
    } else {
    
      assert.equal(1, result.length);
      deferred.resolve(result[0]._id.toString());
    }
  });
  return deferred.promise; 
} 

function removeStoryFromDb(db) {

  var deferred = Q.defer();
  db.collection("story").remove({_id: ObjectID(storyId)}, function(err, result) {

    db.close();  
  
    if (err) {
  
      deferred.reject(new Error(err));
    } else {
    
      deferred.resolve();
    }
  });
  return deferred.promise; 
} 

describe('story view', function() {

  before(function(done) {
        
    this.server = http.createServer(app).listen(3000);
    this.browser = new Browser({site: 'http://localhost:3000'});
    
    connectToDb()
    .then(addStoryToDb)
    .then(function(id) {
      
      storyId = id;
    })
    .then(done, done);
  });
  
  beforeEach(function(done) {
  
    var browser = this.browser;
    browser.visit('/story/' + storyId)
    .then(function() {
    
      assert.ok(browser.success);
    })
    .then(done, done);
  });
  
  it('should show story details', function() {
    
    var input = this.browser.query('.main-panel .header input');
    assert.equal(storyData.title, input.getAttribute('value'));
    assert.equal(storyData.description, this.browser.text('.main-panel .description textarea'));
  });
  it('should allow editing story details', function(done) {
    
    var title = "new title";
    var description = "new description";
    
    var browser = this.browser;
    browser.fill('.main-panel .header input', title);
    browser.fill('.main-panel .description textarea', description);

    clickSaveButton.bind({browser: browser, id: "uuid-" + storyId})()
    .then(browser.reload())
    .then(function() {
      
      assert.equal(browser.query('.main-panel .header input').getAttribute('value'), title);
      assert.equal(browser.text('.main-panel .description textarea'), description);
    })
    .then(done, done);
  });
  it('should allow creating tasks', function(done) {
  
    panels = this.browser.queryAll('#panel-container .panel')
    assert.equal(panels.length, 0);
  
    var browser = this.browser;
    clickAddButton.bind(browser)()
    .then(clickAddButton.bind(browser))
    .then(clickAddButton.bind(browser))
    .then(function() {
    
      panels = browser.queryAll('#panel-container .panel')
      assert.equal(panels.length, 3);  
    })
    .then(done, done);
  });
  it('should allow editing a tasks\'s title and description', function(done) {
  
    assert.equal(panels.length, 3);
  
    var title = "test title";
    var description = "test description";
    
    var id = panels[1].getAttribute('id');
    var browser = this.browser;
    
    browser.fill('#' + id + ' .header input', title);
    browser.fill('#' + id + ' .description textarea', description);

    clickSaveButton.bind({browser: browser, id: id})()
    .then(browser.reload())
    .then(function() {
      
      assert.equal(browser.query('#' + id + ' .header input').getAttribute('value'), title);
      assert.equal(browser.text('#' + id + ' .description textarea'), description);
    })
    .then(done, done);      
  });
  it('should allow changing the priority of tasks', function(done) {

    assert.equal(panels.length, 3);

    var id = panels[1].getAttribute('id');
    var browser = this.browser;
    
    //    <=
    // [0]   [1]   [1]
    //
    // [1]=> [0]=> [2]
    // 
    // [2]   [2]   [0]
    //          <= 
    
    browser.wait()
    .then(function() {
    
      browser.window.moveItemUp(id);
    })
    .then(clickSaveButton.bind({browser: browser, id: id}))
    .then(browser.reload())
    .then(function() {
    
      var panel = browser.query('#panel-container .panel:first-child');
      assert.equal(id, panel.getAttribute('id'));
      panel = browser.query('#panel-container .panel:nth-child(2)');
      id = panels[0].getAttribute('id');
      assert.equal(id, panel.getAttribute('id'));
    })
    .then(function() {
    
      id = panels[0].getAttribute('id');
      browser.window.moveItemDown(id);
    })
    .then(clickSaveButton.bind({browser: browser, id: id}))
    .then(browser.reload())
    .then(function () {
    
      var panel = browser.query('#panel-container .panel:last-child');
      assert.equal(id, panel.getAttribute('id'));
      panel = browser.query('#panel-container .panel:nth-child(2)');
      id = panels[2].getAttribute('id');
      assert.equal(id, panel.getAttribute('id'));      
    })
    .then(done, done);
  });
  it('should allow removing tasks', function(done) {
  
    assert.equal(panels.length, 3);
  
    var browser = this.browser;
    browser.onconfirm('Do you want to remove the item and its assigned objects?', true);
  
    clickRemoveButton.bind({browser: browser, id: panels[0].getAttribute('id')})()
    .then(clickRemoveButton.bind({browser: browser, id: panels[1].getAttribute('id')}))
    .then(clickRemoveButton.bind({browser: browser, id: panels[2].getAttribute('id')}))
    .then(function() {
    
      assert.equal(browser.query('#panel-container .panel', null));  
    })
    .then(done, done);
  });
  after(function(done) {
  
    var server = this.server;
    connectToDb()
    .then(removeStoryFromDb)
    .then(function() {
    
      server.close();
    })
    .then(done, done);
  });
})