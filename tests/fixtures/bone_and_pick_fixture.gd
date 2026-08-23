class_name BoneAndPickFixture
extends RefCounted

const TICKS_PER_WORKDAY := WorkplaceController.TICKS_PER_WORKDAY
const Commands = preload("res://src/workplace/workplace_commands.gd")

var _seed: int
var _root: AppRoot
var _controller: WorkplaceController


func _init(seed: int = 0) -> void:
	_seed = seed
	_root = AppRoot.new()
	_root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	_root.event_seed = seed
	_root.boot()
	_controller = WorkplaceController.new()
	_controller.configure(_root, _root.active_catalog, seed)
	_controller.accessibility_settings.auto_pause_major_events = false


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if is_instance_valid(_controller):
		_controller.free()
	if is_instance_valid(_root):
		_root.free()


func run_to_first_incident() -> void:
	while active_occurrence_view().is_empty() and int(_controller.read_view().tick) < 1000:
		_controller.advance_frame(SimulationClock.TICK_SECONDS)


func active_workers() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for worker in _controller.read_view().workers:
		if StringName(worker.employment_state) == &"active":
			active.append(worker.duplicate(true))
	return active


func active_occurrence_view() -> Dictionary:
	var view := _controller.read_view()
	var selected_id := StringName(view.get("selected_incident_id", &""))
	for occurrence in view.active_incidents:
		if StringName(occurrence.id) == selected_id:
			return occurrence.duplicate(true)
	return view.active_incidents[0].duplicate(true) if not view.active_incidents.is_empty() else {}


func document_issue(issue: StringName) -> bool:
	var occurrence := active_occurrence_view()
	if issue.is_empty() or occurrence.is_empty() or issue != StringName(occurrence.issue):
		return false
	var result := _controller.apply_command(Commands.ProposeActionCommand.new(&"document", StringName(occurrence.id)))
	return bool(result.get("executed", false))


func advance_ticks(count: int) -> void:
	if count > 0:
		_controller.advance_frame(float(count) * SimulationClock.TICK_SECONDS)


func complete_workdays(count: int) -> void:
	if count <= 0:
		return
	var target_tick := int(_controller.read_view().tick) + count * TICKS_PER_WORKDAY
	while int(_controller.read_view().tick) < target_tick:
		_drive_active_occurrences()
		_controller.advance_frame(SimulationClock.TICK_SECONDS)
	_drive_active_occurrences()


func negotiate_and_ratify(strategy: StringName) -> Dictionary:
	return _controller.apply_command(Commands.EnterNegotiationCommand.new(strategy))


func save_and_restore() -> BoneAndPickFixture:
	var saved := SaveService.round_trip_for_test(durable_snapshot())
	var restored := BoneAndPickFixture.new(int(saved.get("seed", 0)))
	restored._controller.restore_durable(saved)
	return restored


func durable_snapshot() -> Dictionary:
	var view := _controller.durable_snapshot()
	view["schema_version"] = SaveService.SCHEMA_VERSION
	view["chapter"] = &"bone_and_pick"
	return view


func _drive_active_occurrences() -> void:
	for occurrence in _controller.read_view().active_incidents:
		var occurrence_id := StringName(occurrence.id)
		if StringName(occurrence.event_kind) == EventDefinition.POSITIVE_KIND:
			_controller.apply_command(Commands.AcknowledgeEventCommand.new(occurrence_id))
			continue
		var grievance := _case_view(occurrence_id)
		if grievance.is_empty():
			continue
		if StringName(grievance.phase) in [&"reported", &"investigating"]:
			_controller.apply_command(Commands.ProposeActionCommand.new(&"document", occurrence_id))
			grievance = _case_view(occurrence_id)
		if grievance.get("action_history", []).is_empty():
			_controller.apply_command(Commands.ProposeActionCommand.new(&"informal", occurrence_id))
		_controller.apply_command(Commands.ApplyRemedyCommand.new(occurrence_id, &"fixture_settlement"))


func _case_view(grievance_id: StringName) -> Dictionary:
	for grievance in _controller.durable_snapshot().grievances:
		if StringName(grievance.id) == grievance_id:
			return grievance.duplicate(true)
	return {}
