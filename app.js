var express = require('express');
var bodyParser = require('body-parser');
var tasks = require('./routes/tasks');
var stories = require('./routes/stories');
var sprints = require('./routes/sprints');
var app = express();

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: true}));
app.use('/api', tasks);
app.use('/api', stories);
app.use('/api', sprints);

module.exports = app;