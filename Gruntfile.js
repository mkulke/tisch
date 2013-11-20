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
			},
			task: {

				filesSrc: ['test/functional/task.coffee.js']
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
					'coffee/story.coffee.js': 'coffee/story.coffee',
					'coffee/sprint.coffee.js': 'coffee/sprint.coffee',
					'coffee/index.coffee.js': 'coffee/index.coffee',
		     	'coffee/shared.coffee.js': 'coffee/shared.coffee',
		     	'test/unit/sprint.coffee.js': 'test/unit/sprint.coffee',
		      'test/unit/task.coffee.js': 'test/unit/task.coffee',
		      'test/unit/story.coffee.js': 'test/unit/story.coffee',
		      'test/unit/shared.coffee.js': 'test/unit/shared.coffee',
		      'test/functional/task.coffee.js': 'test/functional/task.coffee'
		    }
  		},
		},
		watch: {

		 	coffee: {

		    	files: ['coffee/*.coffee', 'test/unit/*.coffee', 'test/functional/*.coffee'],
		    	tasks: 'coffee'
		  	}
		},
		mocha_phantomjs: {

			all: ['test/unit/*.html']
		},
    shell: {

        create_db_objects: {

            command: 'mongo test/functional/create_db_objects.js'
        },
        cleanup_db_objects: {

            command: 'mongo test/functional/cleanup_db_objects.js'
        }
    }
	});

	grunt.loadNpmTasks('grunt-mocha-phantomjs');
	grunt.loadNpmTasks('grunt-contrib-watch');
	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.loadNpmTasks('grunt-shell');
	grunt.loadNpmTasks('grunt-ghost');
	grunt.registerTask('server', function() {
  
  	grunt.log.writeln('Starting tisch server.');
  	require('./server.js').start();
	});
	  // A very basic default task.
  grunt.registerTask('whack', 'Log some stuff.', function() {

    grunt.log.write('Logging some stuff...').ok();
  });
	grunt.registerTask('functional_tests', ['shell:create_db_objects', 'ghost:task', 'shell:cleanup_db_objects']);
	//grunt.registerTask('test', ['coffee', 'server', 'ghost']);
	grunt.registerTask('test', ['coffee', 'mocha_phantomjs', 'functional_tests']);
};