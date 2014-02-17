module.exports = function(grunt) {

  grunt.initConfig({

    pkg: grunt.file.readJSON('package.json'),
    ghost: {

      task: {

        filesSrc: ['test/functional/task.coffee.js']
      },
      sprint: {

        filesSrc: ['test/functional/sprint.coffee.js']
      },
      story: {

        filesSrc: ['test/functional/story.coffee.js']
      },
      rt: {

        filesSrc: ['test/functional/rt.coffee.js']
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
          'coffee/parent.coffee.js': 'coffee/parent.coffee',
          'coffee/markdown.coffee.js': 'coffee/markdown.coffee',
          'coffee/sortable.coffee.js': 'coffee/sortable.coffee',
          'test/unit/sprint.coffee.js': 'test/unit/sprint.coffee',
          'test/unit/task.coffee.js': 'test/unit/task.coffee',
          'test/unit/story.coffee.js': 'test/unit/story.coffee',
          'test/unit/shared.coffee.js': 'test/unit/shared.coffee',
          'test/functional/task.coffee.js': 'test/functional/task.coffee',
          'test/functional/sprint.coffee.js': 'test/functional/sprint.coffee',
          'test/functional/story.coffee.js': 'test/functional/story.coffee',
          'test/functional/rt.coffee.js': 'test/functional/rt.coffee'
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

      all: ['test/unit/*.html'],
      story: ['test/unit/story.html']
    },
    shell: {

      create_db_objects: {

        command: 'mongo test/functional/create_db_objects.js',
        options: {

          failOnError: true
        }
      },
      cleanup_db_objects: {

        command: 'mongo test/functional/cleanup_db_objects.js',
        options: {
          
          failOnError: true
        }
      }
    },
    jshint: {

      src: ['*.js']
    },
  });

  grunt.loadNpmTasks('grunt-mocha-phantomjs');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-shell');
  grunt.loadNpmTasks('grunt-ghost');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.registerTask('server', function() {
  
    grunt.log.writeln('Starting tisch server.');
    require('./server.js').start();
  });

  grunt.registerTask('unit', ['coffee', 'mocha_phantomjs:all']);
  grunt.registerTask('unit_story', ['coffee', 'mocha_phantomjs:story']);
  grunt.registerTask('functional_task', ['shell:create_db_objects', 'ghost:task', 'shell:cleanup_db_objects']);
  grunt.registerTask('functional_story', ['shell:create_db_objects', 'ghost:story', 'shell:cleanup_db_objects']);
  grunt.registerTask('functional_sprint', ['shell:create_db_objects', 'ghost:sprint', 'shell:cleanup_db_objects']);
  grunt.registerTask('functional_rt', ['shell:create_db_objects', 'ghost:rt', 'shell:cleanup_db_objects']);
  grunt.registerTask('functional', ['server', 'functional_task', 'functional_story', 'functional_sprint', 'functional_rt']);
  grunt.registerTask('test', ['jshint', 'coffee', 'mocha_phantomjs', 'functional']);
};