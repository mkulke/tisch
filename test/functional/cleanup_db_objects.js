sprintAId = ObjectId("528c95f4eab8b32b76efac0b");
sprintBId = ObjectId("52d7099a9f3c50aef93a88fe");
storyAId = ObjectId("528c961beab8b32b76efac0c");
storyBId = ObjectId("528cc5cb42a7877322b90c2c");

db.sprint.remove({"_meta.test": true});
db.story.remove({$or: [{"_meta.test": true}, {"sprint_id": sprintAId}, {"sprint_id": sprintBId}]});
db.task.remove({$or: [{"_meta.test": true}, {"story_id": storyAId}, {"story_id": storyBId}]});