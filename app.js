var express = require('express');
var bodyParser = require('body-parser');
var tasks = require('./routes/tasks');
var stories = require('./routes/stories');
var sprints = require('./routes/sprints');
var app = express();

app.set('view engine', 'jade');

app.use(express.static(__dirname + '/public/vendor'));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: true}));

app.use('/api', tasks);
app.use('/api', stories);
app.use('/api', sprints);

app.get('/app', function(req, res){
  res.render('task', {test: 'My string'});
});


module.exports = app;