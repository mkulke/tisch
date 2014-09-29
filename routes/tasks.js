var express = require('express');
var router = express.Router();
var _ = require('underscore')._;
var db = require('../lib/postgres.js');
var respondWithError = require('../lib/utils.js').respondWithError;
var respondWithResult = require('../lib/utils.js').respondWithResult;
var constants = require('../lib/constants.json');

router.route('/task').get(function(req, res) {
	db.findTasks()
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/task/:id').get(function(req, res) {
	db.findSingleTask(req.params.id)
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/task/:id/:property').put(function(req, res) {
	db.updateTask(req.params.id, req.get('Rev'), req.params.property, req.body.value)
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/task/:id/:property/:index').put(function(req, res) {
	db.updateIndexedTaskProperty(req.params.id, req.get('Rev'), req.params.property, req.params.index, req.body.value)
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/task').post(function(req, res) {
	db.addTask(_.extend(constants.templates.task, {story_id: req.get('Parent-Id')}))
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/task/:id').delete(function(req, res) {
	db.removeTask(req.params.id, req.get('Rev'))
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

module.exports = router;