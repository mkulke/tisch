ko.components.register('popover-test', {
    viewModel: function(params) {
			$('#popover-test').popover();
    },
    template: {
      fromUrl: 'popover-test'
    }
});