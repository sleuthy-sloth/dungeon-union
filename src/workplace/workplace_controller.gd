class_name WorkplaceController
extends Control

const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceCommandsScript = preload("res://src/workplace/workplace_commands.gd")
const NegotiationComposerScript = preload("res://src/negotiation/bone_and_pick_negotiation_composer.gd")

const ACTIVE_ISSUES: Array[StringName] = [
	&"cave_in_prevention", &"lantern_fume_exposure", &"maintenance_pay",
]
const SPEEDS: Array[int] = [1, 2, 4]
const TICKS_PER_WORKDAY := 240

@export var accessibility_settings: AccessibilitySettings

var _app_root: AppRoot
var _catalog: ContentCatalog
var _clock := SimulationClock.new()
var _simulation: WorkplaceSimulation
var _grievances := GrievanceService.new()
var _organizing: OrganizingService
var _campaign := CampaignState.new(5)
var _tick := 0
var _workday := 1
var _deferred_ticks := 0
var _incidents: Array[Dictionary] = []
var _selected_worker_id: StringName = &""
var _selected_incident_id: StringName = &""
var _last_action_result: Dictionary = {}
var _configured := false
var _dragging := false
var _mine_offset := Vector2.ZERO
var _zoom := 1.0


func _ready() -> void:
	if accessibility_settings == null:
		accessibility_settings = AccessibilitySettings.new()
	if has_node("WorkplaceHUD"):
		var hud: WorkplaceHUD = $WorkplaceHUD
		hud.command_requested.connect(apply_command)
		hud.union_hall_requested.connect(_open_union_hall)
		hud.set_accessibility(accessibility_settings)
	if has_node("UnionHallView"):
		$UnionHallView.configure(_campaign)
		$UnionHallView.set_accessibility(accessibility_settings)
		$UnionHallView.visible = false
	if has_node("MineInputSurface"):
		$MineInputSurface.gui_input.connect(_on_mine_gui_input)
	_ensure_input_actions()
	_apply_camera_transform()


func configure(root: AppRoot, catalog: ContentCatalog, seed: int = 0) -> void:
	if accessibility_settings == null:
		accessibility_settings = AccessibilitySettings.new()
	_app_root = root
	_catalog = catalog
	if _catalog == null:
		return
	var definitions: Array[WorkerDefinition] = []
	if not _catalog.workplace_items.is_empty():
		for worker_id in _catalog.workplace_items[0].worker_ids:
			var definition := _worker_definition(worker_id)
			if definition != null:
				definitions.append(definition)
	_simulation = WorkplaceSimulation.create_from_definitions(seed, definitions)
	_create_organizing_service()
	_configured = true
	if has_node("MineViewport"):
		$MineViewport.configure(_catalog)
		$MineViewport.set_accessibility(accessibility_settings)
	_refresh_presentation()


func advance_frame(real_delta: float) -> void:
	if not _configured or _simulation == null:
		return
	if _clock.paused:
		_refresh_presentation()
		return
	var tick_count := _deferred_ticks + _clock.advance(maxf(0.0, real_delta))
	_deferred_ticks = 0
	var processed_ticks := 0
	for logical_tick in tick_count:
		_simulation.apply_tick()
		_organizing.synchronize_worker_views(_simulation.snapshot().workers)
		processed_ticks += 1
		_tick += 1
		_workday = int(_tick / TICKS_PER_WORKDAY) + 1
		_grievances.advance_deadlines(_tick)
		_complete_terminal_event_runtimes()
		# Integration invariant: every logical simulation tick gets exactly one Task 6 command.
		var snapshot := _simulation.snapshot()
		snapshot["active_issues"] = ACTIVE_ISSUES.duplicate()
		var started: EventDefinition = _app_root.apply_fixed_tick(
			FixedTickEventCommandScript.new(_tick, _workday, snapshot)
		)
		if started != null:
			_record_started_event(started)
			if started.major and accessibility_settings.auto_pause_major_events:
				_clock.paused = true
				_deferred_ticks = tick_count - processed_ticks
				break
	_refresh_presentation()


func apply_command(command: Variant) -> Dictionary:
	if command is WorkplaceCommandsScript.SelectWorkerCommand:
		_selected_worker_id = command.worker_id if _worker_exists(command.worker_id) else &""
		_selected_incident_id = &""
	elif command is WorkplaceCommandsScript.InspectIncidentCommand:
		_selected_incident_id = command.incident_id if _incident_exists(command.incident_id) else &""
	elif command is WorkplaceCommandsScript.PauseCommand:
		_clock.paused = command.paused
	elif command is WorkplaceCommandsScript.SetSpeedCommand:
		if SPEEDS.has(command.speed):
			_clock.speed = float(command.speed)
			_clock.paused = false
	elif command is WorkplaceCommandsScript.ProposeActionCommand:
		_last_action_result = _execute_action(command.action, command.grievance_id)
	elif command is WorkplaceCommandsScript.EnterNegotiationCommand:
		_last_action_result = _enter_negotiation(command.strategy)
	_refresh_presentation()
	return _last_action_result.duplicate(true)


func read_view() -> Dictionary:
	var workers: Array[Dictionary] = []
	if _simulation != null:
		for raw_worker in _simulation.snapshot().workers:
			var worker: Dictionary = raw_worker.duplicate(true)
			var definition := _worker_definition(StringName(worker.id))
			if definition != null:
				worker["display_name"] = definition.display_name
				worker["species"] = definition.species
				worker["job_id"] = definition.job_id
			workers.append(worker)
	var active_incidents: Array[Dictionary] = []
	var incident_history: Array[Dictionary] = []
	for incident in _incidents:
		var copy := incident.duplicate(true)
		var grievance := _grievances.get_state(StringName(incident.id))
		if grievance != null:
			copy["grievance_phase"] = grievance.phase
			copy["evidence_score"] = grievance.evidence_score
			copy["resolved_action"] = grievance.resolved_action
		if grievance != null and grievance.phase in GrievanceState.TERMINAL_PHASES:
			incident_history.append(copy)
		else:
			active_incidents.append(copy)
	var resources := _organizing.resources_snapshot() if _organizing != null else {}
	return {
		"tick": _tick,
		"workday": _workday,
		"paused": _clock.paused,
		"speed": int(_clock.speed),
		"workers": workers,
		"incidents": active_incidents,
		"active_incidents": active_incidents,
		"incident_history": incident_history,
		"selected_worker_id": _selected_worker_id,
		"selected_incident_id": _selected_incident_id,
		"resources": resources,
		"employer_pressure": mini(100, 24 + _workday * 5),
		"last_action_result": _last_action_result.duplicate(true),
		"action_forecasts": _action_forecasts(),
		"zoom": _zoom,
		"pan_offset": _mine_offset,
		"deferred_ticks": _deferred_ticks,
	}


func _process(delta: float) -> void:
	advance_frame(delta)


func _shortcut_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"workplace_pause"):
		apply_command(WorkplaceCommandsScript.PauseCommand.new(not _clock.paused))
	elif event.is_action_pressed(&"workplace_speed_1"):
		apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(1))
	elif event.is_action_pressed(&"workplace_speed_2"):
		apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(2))
	elif event.is_action_pressed(&"workplace_speed_4"):
		apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(4))
	elif event.is_action_pressed(&"workplace_cycle_incident"):
		_cycle_incident()
	elif event.is_action_pressed(&"workplace_union_hall"):
		_open_union_hall()


func _on_mine_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if not event.pressed:
				_dragging = false
			else:
				_dragging = true
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_zoom = clampf(_zoom + direction * 0.08, 0.72, 1.28)
			_apply_camera_transform()
	if event is InputEventMouseMotion and _dragging:
		_mine_offset += event.relative
		_mine_offset.x = clampf(_mine_offset.x, -190.0, 190.0)
		_mine_offset.y = clampf(_mine_offset.y, -115.0, 115.0)
		_apply_camera_transform()
	if event is InputEventMagnifyGesture:
		_zoom = clampf(_zoom * event.factor, 0.72, 1.28)
		_apply_camera_transform()
	if event is InputEventPanGesture:
		_mine_offset -= event.delta * 18.0
		_mine_offset.x = clampf(_mine_offset.x, -190.0, 190.0)
		_mine_offset.y = clampf(_mine_offset.y, -115.0, 115.0)
		_apply_camera_transform()


# Compatibility entry point for non-scene unit callers; the playable scene routes
# primary pointer input through MineInputSurface.
func _unhandled_input(event: InputEvent) -> void:
	if is_inside_tree():
		return
	_on_mine_gui_input(event)


func _create_organizing_service() -> void:
	_organizing = OrganizingService.new(_simulation.snapshot().workers, [], UnionResources.new(40, 5, 2, 2))


func _record_started_event(event: EventDefinition) -> void:
	var affected := _affected_workers_for(event)
	var occurrence_id := StringName("%s@%08d" % [event.id, _tick])
	var incident := IncidentRecord.new(occurrence_id, event.issue, affected, _tick)
	_grievances.report(incident)
	_incidents.append({
		"id": occurrence_id,
		"occurrence_id": occurrence_id,
		"runtime_id": event.id,
		"definition_id": event.id,
		"issue": event.issue,
		"title": _event_title(event.id),
		"description": _event_description(event.id),
		"affected_workers": affected,
		"major": event.major,
		"pattern": _event_pattern(event.id),
	})
	_selected_incident_id = occurrence_id
	if not affected.is_empty():
		_selected_worker_id = affected[0]


func _execute_action(action: StringName, grievance_id: StringName) -> Dictionary:
	var grievance := _grievances.get_state(grievance_id)
	if grievance == null:
		return {"executed": false, "blocker": "Select an active incident first."}
	if action == &"document":
		if grievance.phase in GrievanceState.TERMINAL_PHASES:
			return {"executed": false, "action": action, "blocker": "This grievance action is already complete."}
		if grievance.phase == &"documented":
			return {"executed": false, "action": action, "blocker": "Testimony is already documented."}
		_grievances.add_evidence(grievance_id, EvidenceRecord.new(&"worker_testimony", 2, _tick + 240))
		grievance = _grievances.get_state(grievance_id)
		_organizing.register_grievance(grievance)
		return {"executed": true, "action": action, "summary": "Testimony documented. Compare the four action forecasts."}
	if grievance.phase in GrievanceState.TERMINAL_PHASES:
		return {"executed": false, "blocker": "This grievance action is already complete."}
	var result := _organizing.execute_atomically(
		ActionProposal.new(action, grievance_id, 50, false),
		func() -> bool: return _grievances.transition_action(grievance_id, action)
	)
	result["summary"] = "%s completed with %d ready workers." % [String(action).replace("_", " ").capitalize(), result.ready_workers.size()] if result.executed else result.blocker
	if result.executed:
		var incident: Variant = _incident_for(grievance_id)
		if incident != null:
			_app_root.complete_event(StringName(incident.runtime_id))
	return result


func _enter_negotiation(strategy: StringName) -> Dictionary:
	if strategy != &"safety_first":
		return {"ratified": false, "summary": "That bargaining strategy is not available in this slice."}
	var state := NegotiationComposerScript.new().compose(
		_simulation.snapshot().workers,
		_grievances.snapshot(),
		_organizing.resources_snapshot()
	)
	var resolver := NegotiationResolver.bone_and_pick(state)
	var package := {
		&"safety": resolver.press(&"safety", &"fume_testimony"),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", &"tool_ledger"),
	}
	var result := resolver.ratify(package)
	result["package"] = package
	var safety_clause := String(package.safety.clause_id).replace("_", " ").capitalize()
	var example_worker: StringName = result.yes_votes[0] if not result.yes_votes.is_empty() else (result.no_votes[0] if not result.no_votes.is_empty() else &"")
	result["summary"] = "%s\nSAFETY  %s\nVOTE  %d yes / %d no\n%s" % [
		"TENTATIVE AGREEMENT RATIFIED" if result.ratified else "TENTATIVE AGREEMENT REJECTED",
		safety_clause if not safety_clause.is_empty() else "No safety concession",
		result.yes_votes.size(),
		result.no_votes.size(),
		String(result.explanations.get(example_worker, "No vote explanation available.")),
	]
	return result


func _action_forecasts() -> Dictionary:
	var result := {}
	if _organizing == null:
		return result
	var authoritative := _grievances.get_state(_selected_incident_id)
	if authoritative == null or authoritative.phase in GrievanceState.TERMINAL_PHASES:
		var blocker := "This grievance action is already complete." if authoritative != null else "Select an active incident first."
		for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
			result[action] = {"can_execute": false, "ready_count": 0, "uncertain_count": 0, "blocker": blocker}
		return result
	for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
		var forecast := _organizing.forecast(ActionProposal.new(action, _selected_incident_id, 50, false))
		result[action] = {
			"can_execute": forecast.can_execute,
			"ready_count": forecast.ready_count,
			"uncertain_count": forecast.uncertain_workers.size(),
			"blocker": forecast.blocker,
		}
	return result


func _cycle_incident() -> void:
	var active: Array = read_view().active_incidents
	if active.is_empty():
		return
	var index := -1
	for item_index in active.size():
		if StringName(active[item_index].id) == _selected_incident_id:
			index = item_index
			break
	index = (index + 1) % active.size()
	apply_command(WorkplaceCommandsScript.InspectIncidentCommand.new(StringName(active[index].id)))


func _open_union_hall() -> void:
	_clock.paused = true
	if has_node("UnionHallView"):
		$UnionHallView.configure(_campaign)
		$UnionHallView.visible = true


func _refresh_presentation() -> void:
	var view := read_view()
	if has_node("MineViewport"):
		$MineViewport.update_view(view)
	if has_node("WorkplaceHUD"):
		$WorkplaceHUD.update_view(view)


func _apply_camera_transform() -> void:
	if has_node("MineViewport"):
		$MineViewport.position = Vector2(715, 445) + _mine_offset
		$MineViewport.scale = Vector2.ONE * _zoom
		$MineViewport.queue_redraw()


func _worker_exists(worker_id: StringName) -> bool:
	for worker in read_view().workers:
		if StringName(worker.id) == worker_id:
			return true
	return false


func _incident_exists(incident_id: StringName) -> bool:
	for incident in _incidents:
		if StringName(incident.id) == incident_id:
			return true
	return false


func _incident_for(incident_id: StringName) -> Variant:
	for incident in _incidents:
		if StringName(incident.id) == incident_id:
			return incident
	return null


func _complete_terminal_event_runtimes() -> void:
	for incident in _incidents:
		var grievance := _grievances.get_state(StringName(incident.id))
		if grievance != null and grievance.phase in GrievanceState.TERMINAL_PHASES:
			_app_root.complete_event(StringName(incident.runtime_id))


func _ensure_input_actions() -> void:
	var bindings := {
		&"workplace_pause": KEY_SPACE,
		&"workplace_speed_1": KEY_1,
		&"workplace_speed_2": KEY_2,
		&"workplace_speed_4": KEY_4,
		&"workplace_cycle_incident": KEY_TAB,
		&"workplace_union_hall": KEY_U,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var already_bound := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey and existing.keycode == bindings[action]:
				already_bound = true
		if not already_bound:
			var key := InputEventKey.new()
			key.keycode = bindings[action]
			InputMap.action_add_event(action, key)


func _worker_definition(worker_id: StringName) -> WorkerDefinition:
	if _catalog == null:
		return null
	for worker in _catalog.worker_items:
		if worker != null and worker.id == worker_id:
			return worker
	return null


func _affected_workers_for(event: EventDefinition) -> Array[StringName]:
	var affected: Array[StringName] = []
	if _catalog == null:
		return affected
	for worker in _catalog.worker_items:
		for tag in event.required_worker_tags:
			if worker.event_role_tags.has(tag) and not affected.has(worker.id):
				affected.append(worker.id)
	if affected.is_empty() and not _catalog.worker_items.is_empty():
		affected.append(_catalog.worker_items[0].id)
	return affected


func _event_title(event_id: StringName) -> String:
	return String(event_id).replace("_", " ")


func _event_description(event_id: StringName) -> String:
	match event_id:
		&"cave_in_risk": return "Loose shoring groans over the west excavation face. Brakka has stopped work pending inspection."
		&"lantern_fumes": return "Blue lantern smoke pools below the gallery roof. Drusk reports dizziness and poor ventilation."
		&"unpaid_maintenance": return "Clatter's repair ledger shows another unpaid hour at the tool bench."
		&"adventurer_alarm": return "The alarm roster leaves Ember alone at the post during the busiest haul."
		&"foreman_intimidation": return "Foreman Grint is questioning workers one at a time beside the maintenance bench."
		_: return "Workers are coordinating mutual aid while the shift is under pressure."


func _event_pattern(event_id: StringName) -> String:
	match event_id:
		&"cave_in_risk": return "XXX / unstable stone"
		&"lantern_fumes": return "/// / airborne hazard"
		&"unpaid_maintenance": return "+++ / wage record"
		_: return "!!! / active incident"
