module.exports = function(grunt) {

	grunt.initConfig({

    pkg: grunt.file.readJSON('package.json'),
		ghost: {

			test: {

				filesSrc: ['test/functional/test.js']
			},
			two_clients: {

				filesSrc: ['test/functional/two_clients.js']
			},
			index: {

				filesSrc: ['test/functional/index.js']
			}				
		},
	});

	grunt.loadNpmTasks('grunt-ghost');
	grunt.registerTask('test', ['ghost']);
};