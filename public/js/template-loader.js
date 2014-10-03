var templateLoader = {
  loadTemplate: function(name, templateConfig, callback) {
    console.log(templateConfig);

    $.get('/app/component/' + templateConfig.fromUrl, function (result) {
      ko.components.defaultLoader.loadTemplate(name, result, callback);
    });
  }
};
ko.components.loaders.unshift(templateLoader);