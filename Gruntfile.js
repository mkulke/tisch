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
		coffee: {

			compile: {

		    options: {

		      sourceMap: true,
		      bare: true
		    },
		    files: {

		      'static/whack.js': 'static/task.coffee'
		    }
  		},
		},
		watch: {
		  coffee: {
		    files: ['static/*.coffee'],
		    tasks: 'coffee'
		  }
		}
	});

	grunt.loadNpmTasks('grunt-contrib-watch');
	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.loadNpmTasks('grunt-ghost');
	grunt.registerTask('server', function() {
  
  	grunt.log.writeln('Starting tisch server.');
  	require('./server.js').start();
	});
	grunt.registerTask('test', ['coffee', 'server', 'ghost']);
};