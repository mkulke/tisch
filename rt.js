var messages = require('./messages.json');
var _ = require('underscore')._;
var io = require('socket.io');

var registrations = [];
var socket;

var listen = function(server) {

  socket = io.listen(server);

  socket.enable('browser client etag');
  socket.enable('browser client gzip'); 
  socket.enable('browser client minification');
  socket.set('log level', 1);

  socket.on('connection', function(client) {

    console.log(["client connected, id:", client.id].join(" "));
    //clients.push(client);
    client.on('register', function(data) {

      _.each(data, function(registration) {

        _.extend(registration, {client: client});
      });
      registrations = registrations.concat(data);
      //console.log(["registrations content:", JSON.stringify(registrations)].join(" "));
    });

    client.on('unregister', function(indices) {

      var unregistered;

      unregistered = function(registration) {

        return (registration.client === client) && (_.contains(indices, registration.index));
      };
      registrations = _.reject(registrations, unregistered);
    });

    client.on('disconnect', function() {
    
      var clientEntry;

      console.log(["client disconnected, id:", client.id].join(" "));

      //clients = _.without(clients, client); 
      
      clientEntry = function(registration) {

        return (registration.client === client);
      };
      registrations = _.reject(registrations, clientEntry);
      //console.log(["registrations content:", JSON.stringify(registrations)].join(" "));
    });
  });
};

var notify = function(notifications) {

  _.each(notifications, function (notification) {

    notification.client.emit('notify', _.omit(notification, 'client'));
  });
};

exports.listen = listen;
exports.notify = notify;
exports.registrations = function() {

  return registrations;
};