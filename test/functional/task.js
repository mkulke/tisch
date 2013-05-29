var http = require('http');
var Browser = require('zombie');
var assert = require('assert');
var app = require('../../server');
var Q = require('q');
var MongoClient = require('mongodb').MongoClient;
var ObjectID = require('mongodb').ObjectID;

var taskData = {

 _rev : 0,
 description: 'initial description',
 initial_estimation: 2.5,
 remaining_time: 1.5,
 time_spent: 1,
 priority: 1,
 story_id: ObjectID(),
 summary: 'initial summary' 
}

var taskId;

process.env.NODE_ENV = 'test';

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

function addTaskToDb(db) {

  var deferred = Q.defer(); 
  db.collection("task").insert(taskData, function(err, result) {

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

function removeTaskFromDb(db) {

  var deferred = Q.defer();
  db.collection("task").remove({_id: ObjectID(taskId)}, function(err, result) {

    db.close();  
  
    if (err) {
  
      deferred.reject(new Error(err));
    } else {
    
      deferred.resolve();
    }
  });
  return deferred.promise; 
} 

describe('task view', function() {

  before(function(done) {
        
    this.server = http.createServer(app).listen(3000);
    this.browser = new Browser({site: 'http://localhost:3000'});
    
    connectToDb()
    .then(addTaskToDb)
    .then(function(id) {
      
      taskId = id;
    })
    .then(done, done);
  });
  
  beforeEach(function(done) {
  
    var browser = this.browser;
    browser.visit('/task/' + taskId)
    .then(function() {
    
      assert.ok(browser.success);
    })
    .then(done, done);
  });
  
  it('should show task details', function() {
    
    var input = this.browser.query('.main-panel .header input[name="summary"]');
    assert.equal(taskData.summary, input.getAttribute('value'));
    assert.equal(taskData.description, this.browser.text('.main-panel .description textarea'));
  });
  it('should allow editing task details', function(done) {
    
    var summary = "new summary";
    var description = "new description";
    var initialEstimation = "3";
    var remainingTime = "1.5";
    var timeSpent = "1.5";
    
    var browser = this.browser;
    browser.fill('.main-panel input[name="summary"]', summary);
    browser.fill('.main-panel textarea[name="description"]', description);
    browser.fill('.main-panel input[name="initial_estimation"]', initialEstimation);
    browser.fill('.main-panel input[name="remaining_time"]', remainingTime);
    browser.fill('.main-panel input[name="time_spent"]', timeSpent);

    clickSaveButton.bind({browser: browser, id: "uuid-" + taskId})()
    .then(browser.wait())
    .then(browser.reload())
    .then(function() {
      
      assert.equal(browser.query('.main-panel input[name="summary"]').getAttribute('value'), summary);
      assert.equal(browser.text('.main-panel textarea[name="description"]'), description);
      assert.equal(browser.query('.main-panel input[name="initial_estimation"]').getAttribute('value'), initialEstimation);
      assert.equal(browser.query('.main-panel input[name="remaining_time"]').getAttribute('value'), remainingTime);
      assert.equal(browser.query('.main-panel input[name="time_spent"]').getAttribute('value'), timeSpent);      
    })
    .then(done, done);
  });
  it('should not accept non-number strings in the time fields.', function(done) {

    // changed to those values above.

    var initialEstimation = "3";
    var remainingTime = "1.5";
    var timeSpent = "1.5";

    var browser = this.browser;
    browser.fill('.main-panel input[name="initial_estimation"]', "a")
    .fill('.main-panel input[name="remaining_time"]', "b")
    .fill('.main-panel input[name="time_spent"]', "c");

    clickSaveButton.bind({browser: browser, id: "uuid-" + taskId})()
    .then(browser.wait())
    .then(browser.reload())
    .then(function() {
      
      assert.equal(browser.query('.main-panel input[name="initial_estimation"]').getAttribute('value'), initialEstimation);
      assert.equal(browser.query('.main-panel input[name="remaining_time"]').getAttribute('value'), remainingTime);
      assert.equal(browser.query('.main-panel input[name="time_spent"]').getAttribute('value'), timeSpent);      
    })
    .then(done, done);
  });
  after(function(done) {
  
    var server = this.server;
    connectToDb()
    .then(removeTaskFromDb)
    .then(function() {
    
      server.close();
    })
    .then(done, done);
  });
})