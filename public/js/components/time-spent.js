ko.components.register('time-spent', {
    viewModel: function(params) {
      $('#time-spent').datepicker({
        format: "yyyy-mm-dd"
      });
    },
    template: {
      fromUrl: 'time-spent'
    }
});