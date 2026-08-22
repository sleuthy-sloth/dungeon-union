class_name EventEngine
extends RefCounted

const EventDefinitionScript = preload("res://src/events/event_definition.gd")

var _events: Array[EventDefinitionScript] = []


func _init(events: Array = []) -> void:
	for event in events:
		if event is EventDefinitionScript:
			_events.append(event)


func eligible(snapshot: Dictionary) -> Array[EventDefinitionScript]:
	var matches: Array[EventDefinitionScript] = []
	var tick := int(snapshot.get("tick", 0))
	var active_issues: Array = snapshot.get("active_issues", [])
	var worker_tags: Array = snapshot.get("worker_tags", [])
	for event in _events:
		if tick < event.minimum_tick:
			continue
		if not event.issue.is_empty() and not active_issues.has(event.issue):
			continue
		if not _contains_all(worker_tags, event.required_worker_tags):
			continue
		matches.append(event)
	return matches


func _contains_all(available: Array, required: Array[StringName]) -> bool:
	for required_tag in required:
		if not available.has(required_tag):
			return false
	return true
