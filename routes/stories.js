var express = require('express');
var router = express.Router();
var _ = require('underscore')._;
var db = require('../lib/postgres.js');
var respondWithError = require('../lib/utils.js').respondWithError;
var respondWithResult = require('../lib/utils.js').respondWithResult;

router.route('/story').get(function(req, res) {
	db.findStories()
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

router.route('/story/:id').get(function(req, res) {
	db.findSingleStory(req.params.id)
	.then(_.partial(respondWithResult, res))
	.fail(_.partial(respondWithError, res));
});

module.exports = router;