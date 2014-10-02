var model = (function () {
  var loadTask = function (id, doneFn) {
    $.get('/api/task/' + id)
    .done(doneFn)
    .fail(function() {
      // TODO
    });
  };

  var persist = function(id, rev, property, value, doneFn) {
    $.ajax({
      type: 'PUT',
      headers: {Rev: rev},
      url: '/api/tasik/' + id + '/' + property,
      contentType: "application/json",
      data: JSON.stringify({value: value})
    })
    .done(doneFn)
    .fail(function (jqXHR, textStatus, errorThrown) {
      var message;

      if (jqXHR.status === 0) {
        message = 'Could not connect to backend. Verify network.';
      } else if (jqXHR.status == 404) {
        message = 'Requested resource not found.';
      } else if (jqXHR.status == 500) {
        message = jqXHR.responseText + '.';
      } else if (errorThrown === 'parsererror') {
        message = 'JSON parsing error';
      } else if (errorThrown === 'timeout') {
        message = 'Connection to backend timed out.';
      } else if (exception === 'abort') {
        message = 'The backend transaction has been aborted by the client';
      } else {
        message = 'Uncaught Error (' + jqXHR.responseText + ').';
      }

      viewModel.error.title('Problem');
      viewModel.error.message(message);
      $('#error-modal').modal();
    });
  };

  return {
    loadTask: loadTask,
    persist: persist
  };
})();

var viewModel = (function() {
  var task = {};

  var error = {
    title: ko.observable('Test'),
    message: ko.observable('Toast')
  };

  var mapTask = function(data) {
    var mapping, observables;

    mapping = {
      copy: ['_id', '_rev'],
      ignore: ['links', 'remaining_time', 'time_spent']
    };

    observables = ko.mapping.fromJS(data, mapping);
    _.chain(observables).pick(_.isFunction).each(function(value, key) {
      value.extend({
        rateLimit: {
          timeout: 500,
          method: "notifyWhenChangesStop"
        }
      });

      value.subscribe(function (newValue) {
        model.persist(task._id, task._rev, key, newValue, function() {
          task._rev += 1;
        });
      });
    });
    _.extend(task, observables);
  };

  return {
    error: error,
    mapTask: mapTask,
    task: task
  };
})();

$(function () {
  model.loadTask(1, function (data) {
    viewModel.mapTask(data);
    ko.applyBindings(viewModel);
  });
});