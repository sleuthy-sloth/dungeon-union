class_name WorkplaceController
extends Control

const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")
const WorkplaceCommandsScript = preload("res://src/workplace/workplace_commands.gd")
const NegotiationComposerScript = preload("res://src/negotiation/bone_and_pick_negotiation_composer.gd")
const SaveServiceScript = preload("res://src/save/save_service.gd")

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
var _seed := 0
var _save_path := ""
var _save_service := SaveServiceScript.new()
var _negotiation_state: Dictionary = {}


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
		$UnionHallView.closed.connect(_return_focus_from_hall)
		$UnionHallView.visible = false
	if has_node("MineInputSurface"):
		$MineInputSurface.gui_input.connect(_on_mine_gui_input)
	_ensure_input_actions()
	_apply_camera_transform()


func configure(
	root: AppRoot,
	catalog: ContentCatalog,
	seed: int = 0,
	save_path: String = "",
	recover_existing: bool = false
) -> void:
	if accessibility_settings == null:
		accessibility_settings = AccessibilitySettings.new()
	_app_root = root
	_catalog = catalog
	_seed = seed
	_save_path = save_path
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
	if recover_existing and not _save_path.is_empty():
		var recovered := _save_service.load_campaign(_save_path)
		if not recovered.is_empty():
			restore_durable(recovered)
	_autosave()
	if has_node("MineViewport"):
		$MineViewport.configure(_catalog)
		$MineViewport.set_accessibility(accessibility_settings)
	_refresh_presentation()
	if has_node("WorkplaceHUD"):
		$WorkplaceHUD.call_deferred(&"focus_initial")


func apply_accessibility(settings: AccessibilitySettings) -> void:
	accessibility_settings = settings.normalized_copy()
	if has_node("WorkplaceHUD"):
		$WorkplaceHUD.set_accessibility(accessibility_settings)
	if has_node("MineViewport"):
		$MineViewport.set_accessibility(accessibility_settings)
	if has_node("UnionHallView"):
		$UnionHallView.set_accessibility(accessibility_settings)


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
		var previous_workday := _workday
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
		if _workday != previous_workday:
			# One logical boundary closes the old shift and opens the next one.
			_autosave()
			_autosave()
		if started != null and started.major and accessibility_settings.auto_pause_major_events:
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
	elif command is WorkplaceCommandsScript.AcknowledgeEventCommand:
		_last_action_result = _acknowledge_event(command.occurrence_id)
	elif command is WorkplaceCommandsScript.PauseCommand:
		_clock.paused = command.paused
	elif command is WorkplaceCommandsScript.SetSpeedCommand:
		if SPEEDS.has(command.speed):
			_clock.speed = float(command.speed)
			_clock.paused = false
	elif command is WorkplaceCommandsScript.ProposeActionCommand:
		_last_action_result = _execute_action(command.action, command.grievance_id)
	elif command is WorkplaceCommandsScript.ApplyRemedyCommand:
		_last_action_result = _apply_remedy(command.grievance_id, command.remedy_id)
	elif command is WorkplaceCommandsScript.EnterNegotiationCommand:
		_last_action_result = _enter_negotiation(command.strategy)
	elif command is WorkplaceCommandsScript.ManualSaveCommand:
		_last_action_result = _manual_save()
	elif command is WorkplaceCommandsScript.ManualLoadCommand:
		_last_action_result = _manual_load()
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
		if StringName(incident.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
			if StringName(incident.get("completion", &"active")) == &"acknowledged":
				incident_history.append(copy)
			else:
				active_incidents.append(copy)
			continue
		var grievance := _grievances.get_state(StringName(incident.id))
		if grievance != null:
			copy["grievance_phase"] = grievance.phase
			copy["evidence_score"] = grievance.evidence_score
			copy["resolved_action"] = grievance.resolved_action
			copy["action_history"] = grievance.action_history.duplicate()
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


func durable_snapshot() -> Dictionary:
	if not _configured or _simulation == null:
		return {}
	return {
		"controller_version": 1,
		"seed": _seed,
		"tick": _tick,
		"workday": _workday,
		"deferred_ticks": _deferred_ticks,
		"clock": {
			"speed": _clock.speed,
			"paused": _clock.paused,
			"accumulator": _clock.accumulator,
		},
		"simulation": _simulation.durable_snapshot(),
		"grievances": _grievances.snapshot(),
		"resources": _organizing.resources_snapshot() if _organizing != null else {},
		"incidents": _incidents.duplicate(true),
		"event_progress": _app_root.event_progress_view() if _app_root != null else {},
		"negotiation": _negotiation_state.duplicate(true),
		"campaign": _campaign.read_view(),
		"accessibility": accessibility_settings.to_dictionary(),
	}


func restore_durable(view: Dictionary) -> bool:
	for required_key in ["seed", "simulation", "grievances", "resources", "incidents", "event_progress", "campaign"]:
		if not view.has(required_key):
			return false
	if not view.simulation is Dictionary or not view.grievances is Array or not view.resources is Dictionary or not view.incidents is Array:
		return false
	var restored_seed := int(view.get("seed", 0))
	var restored_simulation := WorkplaceSimulation.restore(restored_seed, view.simulation)
	var restored_tick := int(restored_simulation.snapshot().get("tick", 0))
	if int(view.get("tick", restored_tick)) != restored_tick:
		return false
	var restored_grievances := GrievanceService.restore(view.grievances, restored_tick)
	var restored_organizing := OrganizingService.restore(
		restored_simulation.snapshot().workers,
		restored_grievances.snapshot(),
		view.resources,
		restored_grievances
	)
	var restored_incidents: Array[Dictionary] = []
	for raw_incident in view.incidents:
		if not raw_incident is Dictionary:
			return false
		restored_incidents.append(raw_incident.duplicate(true))
	_seed = restored_seed
	_simulation = restored_simulation
	_tick = restored_tick
	_workday = maxi(1, int(view.get("workday", int(_tick / TICKS_PER_WORKDAY) + 1)))
	_deferred_ticks = maxi(0, int(view.get("deferred_ticks", 0)))
	_grievances = restored_grievances
	_organizing = restored_organizing
	_incidents = restored_incidents
	_campaign = CampaignState.restore(view.campaign)
	_negotiation_state = view.get("negotiation", {}).duplicate(true)
	var clock_view: Dictionary = view.get("clock", {})
	_clock = SimulationClock.new()
	_clock.speed = float(clock_view.get("speed", 1.0))
	if not SPEEDS.has(int(_clock.speed)):
		_clock.speed = 1.0
	_clock.paused = bool(clock_view.get("paused", false))
	_clock.accumulator = maxf(0.0, float(clock_view.get("accumulator", 0.0)))
	accessibility_settings = AccessibilitySettings.restore(view.get("accessibility", {}))
	if _app_root != null:
		_app_root.restore_event_progress(view.event_progress)
	_selected_worker_id = &""
	_selected_incident_id = &""
	_last_action_result = {}
	_dragging = false
	_mine_offset = Vector2.ZERO
	_zoom = 1.0
	if has_node("WorkplaceHUD"):
		$WorkplaceHUD.set_accessibility(accessibility_settings)
	if has_node("MineViewport"):
		$MineViewport.set_accessibility(accessibility_settings)
	if has_node("UnionHallView"):
		$UnionHallView.configure(_campaign)
		$UnionHallView.set_accessibility(accessibility_settings)
		$UnionHallView.visible = false
	_apply_camera_transform()
	_refresh_presentation()
	return true


func _process(delta: float) -> void:
	advance_frame(delta)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed(&"workplace_cycle_incident") and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		_cycle_incident()
		get_viewport().set_input_as_handled()
		return
	if event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var handled := false
	if event.is_action_pressed(&"workplace_union_hall"):
		_open_union_hall()
		handled = true
	elif event.is_action_pressed(&"workplace_back") and has_node("UnionHallView") and $UnionHallView.visible:
		$UnionHallView.close_view()
		handled = true
	elif event.is_action_pressed(&"workplace_focus_next") or event.is_action_pressed(&"workplace_focus_right"):
		_move_focus(1)
		handled = true
	elif event.is_action_pressed(&"workplace_focus_previous") or event.is_action_pressed(&"workplace_focus_left"):
		_move_focus(-1)
		handled = true
	elif event.is_action_pressed(&"workplace_activate"):
		_activate_focused_control()
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


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
	_organizing = OrganizingService.new(_simulation.snapshot().workers, [], UnionResources.new(40, 5, 2, 2), _grievances)


func _record_started_event(event: EventDefinition) -> void:
	var affected := _affected_workers_for(event)
	var occurrence_id := StringName("%s@%08d" % [event.id, _tick])
	if event.event_kind == EventDefinition.GRIEVANCE_KIND:
		var incident := IncidentRecord.new(occurrence_id, event.issue, affected, _tick)
		_grievances.report(incident)
	_incidents.append(event.occurrence_view(occurrence_id, affected, _tick))
	_selected_incident_id = occurrence_id
	if not affected.is_empty():
		_selected_worker_id = affected[0]


func _execute_action(action: StringName, grievance_id: StringName) -> Dictionary:
	var occurrence: Variant = _incident_for(grievance_id)
	if occurrence != null and StringName(occurrence.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
		return {
			"executed": false,
			"action": action,
			"blocker": "Positive events are acknowledged, not organized as grievances.",
		}
	var grievance := _grievances.get_state(grievance_id)
	if grievance == null:
		return {"executed": false, "blocker": "Select an active incident first."}
	if action == &"document":
		if grievance.phase in GrievanceState.TERMINAL_PHASES:
			return {"executed": false, "action": action, "blocker": "This grievance action is already complete."}
		if grievance.phase == &"documented":
			return {"executed": false, "action": action, "blocker": "Testimony is already documented."}
		_grievances.add_evidence(grievance_id, EvidenceRecord.new(
			StringName(occurrence.get("evidence_id", &"")),
			StringName(occurrence.get("evidence_kind", &"")),
			StringName(occurrence.get("evidence_source", &"")),
			int(occurrence.get("evidence_reliability", 0)),
			_tick + int(occurrence.get("evidence_window_ticks", 0)),
			StringName(occurrence.get("issue", &""))
		))
		grievance = _grievances.get_state(grievance_id)
		return {"executed": true, "action": action, "summary": "Testimony documented. Compare the four action forecasts."}
	if grievance.phase in GrievanceState.TERMINAL_PHASES:
		return {"executed": false, "blocker": "This grievance action is already complete."}
	var result := _organizing.execute(ActionProposal.new(action, grievance_id, 50, false))
	result["summary"] = "%s completed with %d ready workers." % [String(action).replace("_", " ").capitalize(), result.ready_workers.size()] if result.executed else result.blocker
	return result


func _apply_remedy(grievance_id: StringName, remedy_id: StringName) -> Dictionary:
	if _organizing == null:
		return {"applied": false, "blocker": "Organizing services are not configured."}
	var result := _organizing.apply_remedy(grievance_id, remedy_id)
	result["summary"] = "Remedy applied; the case is settled." if result.applied else result.blocker
	if result.applied:
		var occurrence: Variant = _incident_for(grievance_id)
		if occurrence != null:
			_app_root.complete_event(StringName(occurrence.runtime_id))
	return result


func _acknowledge_event(occurrence_id: StringName) -> Dictionary:
	var occurrence: Variant = _incident_for(occurrence_id)
	if occurrence == null:
		return {"acknowledged": false, "blocker": "Select an active positive event first."}
	if StringName(occurrence.get("event_kind", &"grievance")) != EventDefinition.POSITIVE_KIND:
		return {"acknowledged": false, "blocker": "Grievances require an organizing or remedy action."}
	if StringName(occurrence.get("completion", &"active")) != &"active":
		return {"acknowledged": false, "blocker": "This positive event is already acknowledged."}
	occurrence["completion"] = &"acknowledged"
	occurrence["completed_tick"] = _tick
	_app_root.complete_event(StringName(occurrence.runtime_id))
	return {
		"acknowledged": true,
		"occurrence_id": occurrence_id,
		"summary": "Mutual aid acknowledged and added to event history.",
	}


func _enter_negotiation(strategy: StringName) -> Dictionary:
	if strategy != &"safety_first":
		return {"ratified": false, "summary": "That bargaining strategy is not available in this slice."}
	_autosave()
	var state := NegotiationComposerScript.new().compose(
		_simulation.snapshot().workers,
		_grievances.snapshot(),
		_organizing.resources_snapshot()
	)
	var resolver := NegotiationResolver.bone_and_pick(state)
	var safety_evidence := state.first_evidence_id_for_kinds([&"fume_testimony", &"shoring_testimony"])
	var tool_evidence := state.first_evidence_id_for_kinds([&"tool_ledger", &"tool_testimony"])
	var terms := {
		&"safety": resolver.press(&"safety", safety_evidence),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", tool_evidence),
	}
	var package := resolver.issue_tentative_agreement(terms)
	var result := resolver.ratify(package)
	result["package"] = package
	var ratification_outcome := result.duplicate(true)
	ratification_outcome.erase("package")
	ratification_outcome.erase("summary")
	_negotiation_state = {
		"strategy": strategy,
		"issued_agreement": package.duplicate(true),
		"ratification_outcome": ratification_outcome,
	}
	var safety_clause := String(package.safety.clause_id).replace("_", " ").capitalize()
	var example_worker: StringName = result.yes_votes[0] if not result.yes_votes.is_empty() else (result.no_votes[0] if not result.no_votes.is_empty() else &"")
	result["summary"] = "%s\nSAFETY  %s\nVOTE  %d yes / %d no\n%s" % [
		"TENTATIVE AGREEMENT RATIFIED" if result.ratified else "TENTATIVE AGREEMENT REJECTED",
		safety_clause if not safety_clause.is_empty() else "No safety concession",
		result.yes_votes.size(),
		result.no_votes.size(),
		String(result.explanations.get(example_worker, "No vote explanation available.")),
	]
	_autosave()
	return result


func _manual_save() -> Dictionary:
	if _save_path.is_empty():
		return {"saved": false, "blocker": "No campaign save path is configured."}
	var error := _save_service.save_campaign(_save_path, durable_snapshot())
	return {
		"saved": error == OK,
		"error": error,
		"summary": "Campaign saved." if error == OK else "Campaign save failed (%d)." % error,
	}


func _manual_load() -> Dictionary:
	if _save_path.is_empty():
		return {"loaded": false, "blocker": "No campaign save path is configured."}
	var recovered := _save_service.load_campaign(_save_path)
	if recovered.is_empty():
		return {"loaded": false, "blocker": "No valid campaign save is available."}
	if not restore_durable(recovered):
		return {"loaded": false, "blocker": "The campaign save could not be restored."}
	return {"loaded": true, "summary": "Campaign loaded; the workplace view was rebuilt."}


func _autosave() -> Error:
	if _save_path.is_empty() or not _configured:
		return OK
	return _save_service.save_autosave(_save_path, durable_snapshot())


func _action_forecasts() -> Dictionary:
	var result := {}
	if _organizing == null:
		return result
	var selected_occurrence: Variant = _incident_for(_selected_incident_id)
	if selected_occurrence != null and StringName(selected_occurrence.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
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
		$UnionHallView.call_deferred(&"focus_initial")


func _return_focus_from_hall() -> void:
	if has_node("WorkplaceHUD"):
		var hall_button: Button = $WorkplaceHUD.union_hall_button()
		if hall_button != null:
			hall_button.call_deferred(&"grab_focus")


func _move_focus(direction: int) -> void:
	if has_node("UnionHallView") and $UnionHallView.visible:
		$UnionHallView.focus_move(direction)
	elif has_node("WorkplaceHUD"):
		$WorkplaceHUD.focus_move(direction)


func _activate_focused_control() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is BaseButton and owner.visible and not owner.disabled:
		(owner as BaseButton).pressed.emit()


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
		if StringName(incident.get("event_kind", &"grievance")) != EventDefinition.GRIEVANCE_KIND:
			continue
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
		&"workplace_focus_next": KEY_DOWN,
		&"workplace_focus_previous": KEY_UP,
		&"workplace_focus_right": KEY_RIGHT,
		&"workplace_focus_left": KEY_LEFT,
		&"workplace_activate": KEY_ENTER,
		&"workplace_back": KEY_B,
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
