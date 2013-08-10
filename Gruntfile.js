grunt.loadNpmTasks('grunt-ghost');
grunt.registerTask('test', ['ghost']);

ghost: {
	test: {
		files: [{
			src: ['test/functional/*.js']
		}]
	}
}