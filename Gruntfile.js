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

		      'coffee/task.coffee.js': 'coffee/task.coffee',
		      'test/unit/task.coffee.js': 'test/unit/task.coffee'
		    }
  		},
		},
		watch: {

		  coffee: {

		    files: ['coffee/*.coffee', 'test/unit/*.coffee'],
		    tasks: 'coffee'
		  }
		},
		mocha_phantomjs: {

			all: ['test/unit/*.html']
		}
	});

	grunt.loadNpmTasks('grunt-mocha-phantomjs');
	grunt.loadNpmTasks('grunt-contrib-watch');
	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.loadNpmTasks('grunt-ghost');
	grunt.registerTask('server', function() {
  
  	grunt.log.writeln('Starting tisch server.');
  	require('./server.js').start();
	});
	//grunt.registerTask('test', ['coffee', 'server', 'ghost']);
	grunt.registerTask('test', ['coffee', 'mocha_phantomjs']);
};