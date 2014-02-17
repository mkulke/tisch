markdownMixin =

	_setupMarkdown: (renderedObservable) ->

		@markdown = (ko.computed =>

			marked renderedObservable()
		).extend {throttle: common.KEYUP_UPDATE_DELAY}

		@editorVisible = ko.observable false

	hideEditor: (observable, data, event) ->

		if event.keyCode == 27 && @modal != null  

			observable false
		true

	showEditor: (observable) ->

		observable true
		true