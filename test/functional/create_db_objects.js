db.sprint.remove({"_meta.test": true});
db.story.remove({"_meta.test": true});
db.task.remove({"_meta.test": true});

var sprintA = {

	_id: ObjectId("528c95f4eab8b32b76efac0b"),
	_rev: 0,
	description: "Sprint A description",
	start: ISODate("2013-01-01"),
	length: 14,
	color: "blue",
	title: "Test Sprint A",
	_meta: {

		test: true
	}
};
db.sprint.insert(sprintA);

var sprintB = {

	_id: ObjectId("52d7099a9f3c50aef93a88fe"),
	_rev: 0,
	description: "Sprint B description",
	start: ISODate("2013-01-15"),
	length: 14,
	color: "red",
	title: "Test Sprint B",
	_meta: {

		test: true
	}
};
db.sprint.insert(sprintB);

var storyA = {

	_id: ObjectId("528c961beab8b32b76efac0c"),
	_rev: 0,
	color: "yellow",
	description: "Story A description",
	estimation: 5,
	priority: 1,
	sprint_id: ObjectId("528c95f4eab8b32b76efac0b"),
	title: "Test Story A",
	_meta: {

		test: true
	}
};
db.story.insert(storyA);

var storyB = {

	_id: ObjectId("528cc5cb42a7877322b90c2c"),
	_rev: 0,
	color: "red",
	description: "Story B description",
	estimation: 5,
	priority: 2,
	sprint_id: ObjectId("528c95f4eab8b32b76efac0b"),
	title: "Test Story B",
	_meta: {

		test: true
	}
};
db.story.insert(storyB);

var taskA = {

	_id: ObjectId("528c9639eab8b32b76efac0d"),
	_rev: 0, 
	color: "red",
	description: "Task A description",
	initial_estimation: 3,
	priority: 1,
	remaining_time: {

		initial: 1, 
		"2013-01-05": 10
	},
	story_id: ObjectId("528c961beab8b32b76efac0c"),
	summary: "Test Task A",
	time_spent: {

		initial: 0,
		"2012-12-31": 1,
		"2013-01-01": 2,
		"2013-01-02": 3
	},
	_meta: {

		test: true
	}
};
db.task.insert(taskA);

var taskB = {

	_id: ObjectId("52933ac2c3a4f7e8f954e119"),
	_rev: 0, 
	color: "orange",
	description: "Task B description",
	initial_estimation: 5,
	priority: 2,
	remaining_time: {

		initial: 1,
		"2013-01-04": 8.5,
		"2012-01-15": 5
	},
	story_id: ObjectId("528c961beab8b32b76efac0c"),
	summary: "Test Task B",
	time_spent: {

		initial: 0,
		"2013-01-02": 1
	},
	_meta: {

		test: true
	}
};
db.task.insert(taskB);