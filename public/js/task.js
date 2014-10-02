var model = (function () {
  var Model = function () {};

  var loadTask = function (id, doneFn) {
    $.get('/api/task/' + id)
    .done(doneFn)
    .fail(this.handleError);
  };

  var persist = function(id, rev, property, value, doneFn) {
    $.ajax({
      type: 'PUT',
      headers: {Rev: rev},
      url: '/api/task/' + id + '/' + property,
      contentType: "application/json",
      data: JSON.stringify({value: value})
    })
    .done(doneFn)
    .fail(this.handleError);
  };

  Model.prototype = {
    constructor: Model,
    loadTask: loadTask,
    persist: persist
  };

  ajaxMixin.extend(Model.prototype);

  return new Model();
})();

var viewModel = (function() {
  var ViewModel = function() {};

  var task = {};

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
          method: "notifyWhenChangesStop"
        }
      });

      value.subscribe(_.partial(persist, key));
    });

    _.extend(task, observables);
  };

  ViewModel.prototype = {
    constructor: ViewModel,
    error: error,
    task: task,
    mapTask: mapTask
  };

  return new ViewModel();
})();

$(function () {
  model.loadTask(1, function (data) {
    viewModel.mapTask(data);
    ko.applyBindings(viewModel);
  });
});