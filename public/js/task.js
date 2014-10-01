var model = (function () {
  var load = function (id, doneFn) {
    $.get('/api/task/' + id)
    .done(doneFn)
    .fail(function() {
      // TODO
    });
  };

  var persist = function(id, rev, property, value) {
    $.ajax({
      type: 'PUT',
      headers: {Rev: rev},
      url: '/api/task/' + id + '/' + property,
      contentType: "application/json",
      data: JSON.stringify({value: value})
    })
    .done(function () {
      console.log('done');
      // TODO
    })
    .fail(function () {
      // TODO
    });
  };

  return {
    load: load,
    persist: persist
  };
})();

var viewModel = (function() {
  var map = function(data) {
    var mapping, observables, self;

    self = this;

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
        model.persist(self._id, self._rev, key, newValue);
      });
    });
    _.extend(this, observables);
  };

  return {
    map: map
  };
})();

$(function () {
  model.load(1, function (data) {
    viewModel.map(data);
    ko.applyBindings(viewModel);
  });
});