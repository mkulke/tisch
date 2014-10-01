var model = (function () {
  var load = function (id, doneFn) {
    $.get('/api/task/' + id, doneFn);
  };

  var persist = function(property, value) {
    console.log('stub for persisting property ' + property + ' with value ' + value + '.');
  };

  return {
    load: load,
    persist: persist
  };
})();

var viewModel = (function() {
  var map = function(data) {
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

      value.subscribe(_.partial(model.persist, key));
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