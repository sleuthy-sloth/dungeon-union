class_name WorkplaceEventRuntime
extends RefCounted

const EventDefinitionScript = preload("res://src/events/event_definition.gd")
const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceDirectorScript = preload("res://src/events/workplace_director.gd")

var _catalog: ContentCatalog
var _workplace: WorkplaceDefinition
var _director: WorkplaceDirectorScript


func _init(catalog: ContentCatalog, workplace: WorkplaceDefinition, seed: int) -> void:
	_catalog = catalog
	_workplace = workplace
	var events: Array[EventDefinitionScript] = []
	for event_id in _workplace.event_ids:
		var event: EventDefinitionScript = _catalog.events.get(event_id)
		if event != null:
			events.append(event)
	_director = WorkplaceDirectorScript.new(events, seed)


func apply_fixed_tick(command: FixedTickEventCommandScript) -> EventDefinitionScript:
	if command == null:
		return null
	var snapshot := command.snapshot
	snapshot["worker_tags"] = _available_event_role_tags(snapshot)
	_director.update_snapshot(snapshot)
	_director.set_workday(command.workday)
	return _director.choose_and_start(command.tick)


func complete_event(event_id: StringName) -> bool:
	return _director.complete_event(event_id)


func _available_event_role_tags(snapshot: Dictionary) -> Array[StringName]:
	var active_worker_ids: Dictionary[StringName, bool] = {}
	for state in snapshot.get("workers", []):
		if not state is Dictionary:
			continue
		var worker_id := StringName(state.get("id", &""))
		if state.get("employment_state", &"active") == &"active" and _workplace.worker_ids.has(worker_id):
			active_worker_ids[worker_id] = true
	var role_tags: Dictionary[StringName, bool] = {}
	for worker_id in active_worker_ids:
		var worker: WorkerDefinition = _catalog.workers.get(worker_id)
		if worker == null:
			continue
		for role_tag in worker.event_role_tags:
			role_tags[role_tag] = true
	var sorted_tags: Array[StringName] = role_tags.keys()
	sorted_tags.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return sorted_tags
