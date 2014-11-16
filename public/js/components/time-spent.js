ko.components.register('time-spent', {
    viewModel: function(params) {
      $('#time-spent-index').datepicker({
        format: "yyyy-mm-dd"
      });

      ko.extenders.requiresMatch = function(target, regex) {
        //add some sub-observables to our observable
        target.hasError = ko.observable();
        target.validationMessage = ko.observable();

        //define a function to do validation
        function validate(newValue) {
           target.hasError(!regex.test(newValue));
        }

        //initial validation
        validate(target());

        //validate whenever the value changes
        target.subscribe(validate);

        //return the original observable
        return target;
      };

      this.timeSpentValue = ko.observable("3h").extend({requiresMatch: /^\d+h$/});
    },
    template: {
      fromUrl: 'time-spent'
    }
});