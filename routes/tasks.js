var express = require('express');
var router = express.Router();
var Q = require('q');
var db = require('../lib/postgres.js');

router.route('/task').get(function(req, res) {
	db.findTasks()
	.then(function(tasks) {
		return res.json(tasks);
	})
	.fail(function(error) {
		return res.status(500).send(error.message);
	});
});

router.route('/task/:id').get(function(req, res) {
	db.findSingleTask(req.params.id)
	.then(function(task) {
		return res.json(task);
	})
	.fail(function(error) {
		return res.status(500).send(error.message);
	});
});

module.exports = router;