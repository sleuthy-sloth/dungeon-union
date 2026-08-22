class_name WorkplaceController
extends Control

const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceCommandsScript = preload("res://src/workplace/workplace_commands.gd")

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
	_apply_camera_transform()


func configure(root: AppRoot, catalog: ContentCatalog, seed: int = 0) -> void:
	if accessibility_settings == null:
		accessibility_settings = AccessibilitySettings.new()
	_app_root = root
	_catalog = catalog
	if _catalog == null:
		return
	var ids: Array[StringName] = []
	if not _catalog.workplace_items.is_empty():
		ids = _catalog.workplace_items[0].worker_ids.duplicate()
	_simulation = WorkplaceSimulation.create_from_worker_ids(seed, ids)
	_create_organizing_service(ids)
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
		processed_ticks += 1
		_tick += 1
		_workday = int(_tick / TICKS_PER_WORKDAY) + 1
		_grievances.advance_deadlines(_tick)
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
	var incident_views: Array[Dictionary] = []
	for incident in _incidents:
		var copy := incident.duplicate(true)
		var grievance := _grievances.get_state(StringName(incident.id))
		if grievance != null:
			copy["grievance_phase"] = grievance.phase
			copy["evidence_score"] = grievance.evidence_score
		incident_views.append(copy)
	var resources := _organizing.resources_snapshot() if _organizing != null else {}
	return {
		"tick": _tick,
		"workday": _workday,
		"paused": _clock.paused,
		"speed": int(_clock.speed),
		"workers": workers,
		"incidents": incident_views,
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				apply_command(WorkplaceCommandsScript.PauseCommand.new(not _clock.paused))
			KEY_1:
				apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(1))
			KEY_2:
				apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(2))
			KEY_4:
				apply_command(WorkplaceCommandsScript.SetSpeedCommand.new(4))
			KEY_TAB:
				_cycle_incident()
			KEY_U:
				_open_union_hall()
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if not event.pressed:
				_dragging = false
			elif event.button_index == MOUSE_BUTTON_MIDDLE or Rect2(330, 66, 782, 776).has_point(event.position):
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


func _create_organizing_service(worker_ids: Array[StringName]) -> void:
	var workers: Array[WorkerState] = []
	for worker_id in worker_ids:
		var worker := WorkerState.new(worker_id)
		worker.trust = 60
		worker.action_willingness = 65
		workers.append(worker)
	_organizing = OrganizingService.new(workers, [], UnionResources.new(40, 0, 20, 2))


func _record_started_event(event: EventDefinition) -> void:
	var affected := _affected_workers_for(event)
	var incident := IncidentRecord.new(event.id, event.issue, affected, _tick)
	_grievances.report(incident)
	_incidents.append({
		"id": event.id,
		"issue": event.issue,
		"title": _event_title(event.id),
		"description": _event_description(event.id),
		"affected_workers": affected,
		"major": event.major,
		"pattern": _event_pattern(event.id),
	})
	_selected_incident_id = event.id
	if not affected.is_empty():
		_selected_worker_id = affected[0]


func _execute_action(action: StringName, grievance_id: StringName) -> Dictionary:
	var grievance := _grievances.get_state(grievance_id)
	if grievance == null:
		return {"executed": false, "blocker": "Select an active incident first."}
	if action == &"document":
		if grievance.phase in [&"documented", &"resolved"]:
			return {"executed": false, "action": action, "blocker": "Testimony is already documented."}
		_grievances.add_evidence(grievance_id, EvidenceRecord.new(&"worker_testimony", 2, _tick + 240))
		grievance = _grievances.get_state(grievance_id)
		_organizing.register_grievance(grievance)
		return {"executed": true, "action": action, "summary": "Testimony documented. Compare the four action forecasts."}
	if grievance.phase in GrievanceState.TERMINAL_PHASES:
		return {"executed": false, "blocker": "This grievance action is already complete."}
	var result := _organizing.execute(ActionProposal.new(action, grievance_id, 50, false))
	result["summary"] = "%s completed with %d ready workers." % [String(action).replace("_", " ").capitalize(), result.ready_workers.size()] if result.executed else result.blocker
	if result.executed:
		_grievances.resolve(grievance_id)
		_app_root.complete_event(grievance_id)
	return result


func _enter_negotiation(strategy: StringName) -> Dictionary:
	if strategy != &"safety_first":
		return {"ratified": false, "summary": "That bargaining strategy is not available in this slice."}
	var resources := _organizing.resources_snapshot()
	var worker_views := _organizing.worker_views()
	var participation := 0
	if not worker_views.is_empty():
		participation = int(round(100.0 * float(_organizing.forecast(ActionProposal.new(&"informal", &"", 50)).ready_count) / float(worker_views.size())))
	var state := NegotiationState.new(
		_negotiation_evidence(),
		int(resources.solidarity),
		participation,
		int(resources.treasury),
		int(resources.public_support),
		_worker_priorities()
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


func _worker_priorities() -> Dictionary:
	var result := {}
	for worker in _organizing.worker_views():
		result[StringName(worker.id)] = {"trust": int(worker.trust), "priorities": {&"safety": 3, &"schedule": 1, &"tool_maintenance": 1}}
	return result


func _negotiation_evidence() -> Dictionary:
	var safety_evidence := 0
	var tool_evidence := 0
	for incident in _incidents:
		var grievance := _grievances.get_state(StringName(incident.id))
		if grievance == null or grievance.phase not in [&"documented", &"resolved"]:
			continue
		if grievance.issue in [&"cave_in_prevention", &"lantern_fume_exposure", &"unsafe_fumes"]:
			safety_evidence += grievance.evidence_score
		elif grievance.issue == &"maintenance_pay":
			tool_evidence += grievance.evidence_score
	var evidence := {}
	if safety_evidence > 0:
		evidence[&"fume_testimony"] = safety_evidence
	if tool_evidence > 0:
		evidence[&"tool_ledger"] = tool_evidence
	return evidence


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
	if _incidents.is_empty():
		return
	var index := -1
	for item_index in _incidents.size():
		if StringName(_incidents[item_index].id) == _selected_incident_id:
			index = item_index
			break
	index = (index + 1) % _incidents.size()
	apply_command(WorkplaceCommandsScript.InspectIncidentCommand.new(StringName(_incidents[index].id)))


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
