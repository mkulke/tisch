db.createCollection('sprint');
db.createCollection('story');
db.createCollection('task');
db.task.ensureIndex({story_id: 1, priority: 1}, {unique: true});
db.story.ensureIndex({sprint_id: 1, priority: 1}, {unique: true});

sprintAId = ObjectId("528c95f4eab8b32b76efac0b");
sprintBId = ObjectId("52d7099a9f3c50aef93a88fe");
storyAId = ObjectId("528c961beab8b32b76efac0c");
storyBId = ObjectId("528cc5cb42a7877322b90c2c");

var sprintA = {

	_id: sprintAId,
	_rev: 0,
	description: "Sprint A description",
	start: ISODate("2013-01-01"),
	length: 14,
	color: "blue",
	title: "Test Sprint A",
};
db.sprint.insert(sprintA);

var sprintB = {

	_id: sprintBId,
	_rev: 0,
	description: "Sprint B description",
	start: ISODate("2013-01-15"),
	length: 14,
	color: "red",
	title: "Test Sprint B",
};
db.sprint.insert(sprintB);

var storyA = {

	_id: storyAId,
	_rev: 0,
	color: "yellow",
	description: "Story A description",
	estimation: 5,
	priority: 1,
	sprint_id: sprintAId,
	title: "Test Story A",
};
db.story.insert(storyA);

var storyB = {

	_id: storyBId,
	_rev: 0,
	color: "red",
	description: "Story B description",
	estimation: 5,
	priority: 2,
	sprint_id: sprintAId,
	title: "Test Story B",
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
	story_id: storyAId,
	summary: "Test Task A",
	time_spent: {

		initial: 0,
		"2012-12-31": 1,
		"2013-01-01": 2,
		"2013-01-02": 3
	},
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
		"2013-01-15": 5
	},
	story_id: storyAId,
	summary: "Test Task B",
	time_spent: {

		initial: 0,
		"2013-01-02": 1
	},
};
db.task.insert(taskB);
