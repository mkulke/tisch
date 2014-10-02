var ajaxMixin = (function() {
	var handleError = function (jqXHR, textStatus, errorThrown) {
    var message;

    if (jqXHR.status === 0) {
      message = 'Could not connect to backend. Verify network.';
    } else if (jqXHR.status == 404) {
      message = 'Requested resource not found.';
    } else if (jqXHR.status == 500) {
      message =  jqXHR.responseText + '.';
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
	}

	return {
    extend: function(proto) {
    	proto.handleError = handleError;
  	}
	};
})();