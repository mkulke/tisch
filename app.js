var express = require('express');
var bodyParser = require('body-parser');
var tasks = require('./routes/tasks');
var app = express();
var expressJwt = require('express-jwt');
var jwt = require('jsonwebtoken');

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: true}));
app.use('/api', expressJwt({secret: 'secret'}));
app.use('/api', tasks);

app.post('/authenticate', function (req, res) {
  //TODO validate req.body.username and req.body.password
  //if is invalid, return 401
  if (!(req.body.username === 'john.doe' && req.body.password === 'foobar')) {
    res.send(401, 'Wrong user or password');
    return;
  }

  var profile = {
    first_name: 'John',
    last_name: 'Doe',
    email: 'john@doe.com',
    id: 123
  };

  // We are sending the profile inside the token
  var token = jwt.sign(profile, 'secret', { expiresInMinutes: 60*5 });

  res.json({ token: token });
});

module.exports = app;