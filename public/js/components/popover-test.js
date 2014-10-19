ko.components.register('popover-test', {
    viewModel: function(params) {
			$('#popover-test').popover({
        template: '<div class="popover" role="tooltip"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>'
      });

      $('#popover-test .popover-content').datepicker({});
    },
    template: {
      fromUrl: 'popover-test'
    }
});