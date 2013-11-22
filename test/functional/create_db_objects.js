
db.sprint.remove({_id: ObjectId("528c95f4eab8b32b76efac0b")});
var sprint = {

	_id: ObjectId("528c95f4eab8b32b76efac0b"),
	_rev: 0,
	description: "Sprint A description",
	start: ISODate("2013-01-01"),
	length: 14,
	color: "blue",
	title: "Test Sprint A"
};
db.sprint.insert(sprint);

db.story.remove({_id: ObjectId("528c961beab8b32b76efac0c")});
var story = {

	_id: ObjectId("528c961beab8b32b76efac0c"),
	_rev: 0,
	color: "yellow",
	description: "Story A description",
	estimation: 5,
	priority: 1,
	sprint_id: ObjectId("528c95f4eab8b32b76efac0b"),
	title: "Test Story A"
};
db.story.insert(story);

db.story.remove({_id: ObjectId("528cc5cb42a7877322b90c2c")});
story = {

	_id: ObjectId("528cc5cb42a7877322b90c2c"),
	_rev: 0,
	color: "red",
	description: "Story B description",
	estimation: 5,
	priority: 2,
	sprint_id: ObjectId("528c95f4eab8b32b76efac0b"),
	title: "Test Story B"
};
db.story.insert(story);

db.task.remove({_id: ObjectId("528c9639eab8b32b76efac0d")});
var task = {

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
		"2013-01-01": 2
	}
};
db.task.insert(task);