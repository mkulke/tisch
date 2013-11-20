var sprint = {

	_id: ObjectId("528c95f4eab8b32b76efac0b"),
	_rev: 0,
	description: "Sprint description",
	start: ISODate("2013-01-01T00:00:00.000Z"),
	length: 14,
	color: "blue",
	title: "New Sprint"
};
db.sprint.insert(sprint);

var story = {

	_id: ObjectId("528c961beab8b32b76efac0c"),
	_rev: 0,
	color: "yellow",
	description: "dfdfdf",
	estimation: 5,
	priority: 1,
	sprint_id: ObjectId("528c95f4eab8b32b76efac0b"),
	title: "Test Story A"
};
db.story.insert(story);

var task = {

	_id: ObjectId("528c9639eab8b32b76efac0d"),
	_rev: 0, 
	color: "red",
	description: "Task A description",
	initial_estimation: 3,
	priority: 1,
	remaining_time: {

		initial:1, 
		"2013-01-05": 10
	},
	story_id: ObjectId("528c961beab8b32b76efac0c"),
	summary: "Test Task A",
	time_spent: {

		initial:0,
	}
};
db.task.insert(task);