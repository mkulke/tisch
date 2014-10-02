var model = (function () {
  var retrieve = function (id, doneFn, alwaysFn) {
    $.get('/api/task/' + id)
    .done(doneFn)
    .fail(ajax.handleError)
    .always(alwaysFn);
  };

  var persist = function(id, rev, property, value, doneFn) {
    $.ajax({
      type: 'PUT',
      headers: {Rev: rev},
      url: '/api/task/' + id + '/' + property,
      contentType: 'application/json',
      data: JSON.stringify({value: value})
    })
    .done(doneFn)
    .fail(ajax.handleError);
  };

  return {
    retrieve: retrieve,
    persist: persist
  };
})();

var viewModel = (function() {
  var task = {}; //ko.observable(false);

  var error = {
    title: ko.observable(),
    message: ko.observable()
  };

  var persist = function (key, newValue) {
    model.persist(task._id, task._rev, key, newValue, function() {
      task._rev += 1;
    });
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
          method: 'notifyWhenChangesStop'
        }
      });

      value.subscribe(_.partial(persist, key));
    });

    _.extend(task, observables);
  };

  return {
    error: error,
    mapTask: mapTask,
    task: task
  };
})();
