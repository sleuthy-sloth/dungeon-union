class_name BoneAndPickFixture
extends RefCounted

const TICKS_PER_WORKDAY := 240
const NegotiationComposerScript = preload("res://src/negotiation/bone_and_pick_negotiation_composer.gd")

var _seed: int
var _root: AppRoot
var _simulation: WorkplaceSimulation
var _grievances: GrievanceService
var _organizing: OrganizingService
var _campaign := CampaignState.new(5)
var _tick := 0
var _workday := 1
var _active_event_id: StringName = &""
var _active_occurrence: Dictionary = {}
var _grievance_ids: Array[StringName] = []
var _last_negotiation: Dictionary = {}
var _last_strategy: StringName = &""


func _init(seed: int = 0) -> void:
	_seed = seed
	_root = AppRoot.new()
	_root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	_root.event_seed = seed
	_root.boot()
	var definitions: Array[WorkerDefinition] = []
	for worker_id in _root.active_catalog.workplace_items[0].worker_ids:
		definitions.append(_root.active_catalog.workers[worker_id])
	_simulation = WorkplaceSimulation.create_from_definitions(seed, definitions)
	_grievances = GrievanceService.new()
	_organizing = OrganizingService.new(
		_simulation.snapshot().workers,
		[],
		UnionResources.new(40, 5, 2, 2),
		_grievances
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_root):
		_root.free()


func run_to_first_incident() -> void:
	while _active_event_id.is_empty() and _tick < 1000:
		var started := _advance_one_tick()
		if started != null:
			_record_active_event(started)


func active_workers() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for worker in _simulation.snapshot().workers:
		if worker.employment_state == &"active":
			active.append(worker.duplicate(true))
	return active


func active_occurrence_view() -> Dictionary:
	return _active_occurrence.duplicate(true)


func document_issue(issue: StringName) -> bool:
	if issue.is_empty() or _active_occurrence.is_empty() or issue != StringName(_active_occurrence.issue):
		return false
	var grievance_id := StringName(_active_occurrence.id)
	var affected: Array[StringName] = _active_occurrence.affected_workers.duplicate()
	var incident := IncidentRecord.new(grievance_id, StringName(_active_occurrence.issue), affected, _tick)
	if _grievances.report(incident).is_empty():
		return false
	_grievances.add_evidence(grievance_id, EvidenceRecord.new(&"worker_testimony", 2, _tick + TICKS_PER_WORKDAY * 5))
	if not _grievance_ids.has(grievance_id):
		_grievance_ids.append(grievance_id)
	return true


func complete_workdays(count: int) -> void:
	if count <= 0:
		return
	if not _active_event_id.is_empty():
		_root.complete_event(_active_event_id)
		_active_event_id = &""
		_active_occurrence = {}
	for logical_tick in count * TICKS_PER_WORKDAY:
		var started := _advance_one_tick()
		if started != null:
			_root.complete_event(started.id)
	_workday = int(_tick / TICKS_PER_WORKDAY) + 1


func negotiate_and_ratify(strategy: StringName) -> Dictionary:
	_last_strategy = strategy
	if strategy != &"safety_first":
		_last_negotiation = {"ratified": false, "yes_votes": [], "no_votes": []}
		return _last_negotiation.duplicate(true)
	var negotiation_state: NegotiationState = NegotiationComposerScript.new().compose(
		_simulation.snapshot().workers,
		_grievances.snapshot(),
		_organizing.resources_snapshot()
	)
	var resolver := NegotiationResolver.bone_and_pick(negotiation_state)
	var package := {
		&"safety": resolver.press(&"safety", &"fume_testimony"),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", &"tool_ledger"),
	}
	_last_negotiation = resolver.ratify(package)
	_last_negotiation["package"] = package
	return _last_negotiation.duplicate(true)


func save_and_restore() -> BoneAndPickFixture:
	var saved := SaveService.round_trip_for_test(durable_snapshot())
	var restored := BoneAndPickFixture.new(int(saved.get("seed", 0)))
	restored._restore_durable(saved)
	return restored


func durable_snapshot() -> Dictionary:
	return {
		"schema_version": SaveService.SCHEMA_VERSION,
		"seed": _seed,
		"chapter": &"bone_and_pick",
		"tick": _tick,
		"workday": _workday,
		"simulation": _simulation.durable_snapshot(),
		"event_progress": _root.event_progress_view(),
		"grievances": _grievances.snapshot(),
		"resources": _organizing.resources_snapshot(),
		"campaign": _campaign.read_view(),
		"active_occurrence": _active_occurrence.duplicate(true),
		"last_strategy": _last_strategy,
		"negotiation": _last_negotiation.duplicate(true),
	}


func _advance_one_tick() -> EventDefinition:
	_simulation.apply_tick()
	_organizing.synchronize_worker_views(_simulation.snapshot().workers)
	_tick += 1
	_workday = int(_tick / TICKS_PER_WORKDAY) + 1
	_grievances.advance_deadlines(_tick)
	var snapshot := _simulation.snapshot()
	snapshot["active_issues"] = [&"cave_in_prevention", &"lantern_fume_exposure", &"maintenance_pay"]
	return _root.apply_fixed_tick(FixedTickEventCommand.new(_tick, _workday, snapshot))

func _restore_durable(state: Dictionary) -> void:
	_simulation = WorkplaceSimulation.restore(_seed, state.get("simulation", {}))
	_tick = maxi(0, int(state.get("tick", 0)))
	_workday = maxi(1, int(state.get("workday", 1)))
	_grievances = GrievanceService.restore(state.get("grievances", []), _tick)
	_organizing = OrganizingService.restore(_simulation.snapshot().workers, _grievances.snapshot(), state.get("resources", {}), _grievances)
	_campaign = CampaignState.restore(state.get("campaign", {}))
	_root.restore_event_progress(state.get("event_progress", {}))
	_grievance_ids.clear()
	for grievance in _grievances.snapshot():
		_grievance_ids.append(StringName(grievance.id))
	_active_occurrence = state.get("active_occurrence", {}).duplicate(true)
	_active_event_id = StringName(_active_occurrence.get("runtime_id", &""))
	_last_strategy = StringName(state.get("last_strategy", &""))
	_last_negotiation = state.get("negotiation", {}).duplicate(true)


func _record_active_event(event: EventDefinition) -> void:
	_active_event_id = event.id
	var affected: Array[StringName] = []
	for worker in _root.active_catalog.worker_items:
		for tag in event.required_worker_tags:
			if worker.event_role_tags.has(tag) and not affected.has(worker.id):
				affected.append(worker.id)
	if affected.is_empty() and not active_workers().is_empty():
		affected.append(StringName(active_workers()[0].id))
	_active_occurrence = {
		"id": StringName("%s@%08d" % [event.id, _tick]),
		"runtime_id": event.id,
		"definition_id": event.id,
		"issue": event.issue,
		"affected_workers": affected,
	}
