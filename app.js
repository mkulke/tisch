var express = require('express');
var bodyParser = require('body-parser');
var tasks = require('./routes/tasks');
var stories = require('./routes/stories');
var sprints = require('./routes/sprints');
var app = express();

app.set('view engine', 'jade');

app.use(express.static(__dirname + '/public/vendor'));
app.use(express.static(__dirname + '/public/js'));
app.use(express.static(__dirname + '/public/css'));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: true}));

app.use('/api', tasks);
app.use('/api', stories);
app.use('/api', sprints);

app.get('/app/task/:id', function(req, res){
  res.render('task', {id: req.params.id});
});

module.exports = app;