class_name BoneAndPickFixture
extends RefCounted

const TICKS_PER_WORKDAY := 240

var _seed: int
var _root: AppRoot
var _simulation: WorkplaceSimulation
var _grievances: GrievanceService
var _organizing: OrganizingService
var _tick := 0
var _workday := 1
var _active_event_id: StringName = &""
var _grievance_ids: Array[StringName] = []
var _last_negotiation: Dictionary = {}
var _last_strategy: StringName = &""


func _init(seed: int = 0) -> void:
	_seed = seed
	_root = AppRoot.new()
	_root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	_root.event_seed = seed
	_root.boot()
	var worker_ids: Array[StringName] = _root.active_catalog.workplace_items[0].worker_ids.duplicate()
	_simulation = WorkplaceSimulation.create_from_worker_ids(seed, worker_ids)
	_grievances = GrievanceService.new()
	var organizing_workers: Array[WorkerState] = []
	for worker_id in worker_ids:
		var worker := WorkerState.new(worker_id)
		worker.trust = 60
		worker.action_willingness = 65
		organizing_workers.append(worker)
	_organizing = OrganizingService.new(
		organizing_workers,
		[],
		UnionResources.new(40, 0, 20, 2)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_root):
		_root.free()


func run_to_first_incident() -> void:
	while _active_event_id.is_empty() and _tick < 1000:
		var started := _advance_one_tick()
		if started != null:
			_active_event_id = started.id


func active_workers() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for worker in _simulation.snapshot().workers:
		if worker.employment_state == &"active":
			active.append(worker.duplicate(true))
	return active


func document_issue(issue: StringName) -> void:
	if issue.is_empty():
		return
	var grievance_id := StringName("%s_case" % issue)
	var affected: Array[StringName] = []
	for worker in active_workers().slice(0, 2):
		affected.append(StringName(worker.id))
	var incident := IncidentRecord.new(grievance_id, issue, affected, _tick)
	if _grievances.report(incident).is_empty():
		return
	_grievances.add_evidence(grievance_id, EvidenceRecord.new(&"worker_testimony", 2, _tick + TICKS_PER_WORKDAY * 5))
	var state := _grievances.get_state(grievance_id)
	_organizing.register_grievance(state)
	if not _grievance_ids.has(grievance_id):
		_grievance_ids.append(grievance_id)


func complete_workdays(count: int) -> void:
	if count <= 0:
		return
	if not _active_event_id.is_empty():
		_root.complete_event(_active_event_id)
		_active_event_id = &""
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
	var evidence_strength := 0
	for grievance_id in _grievance_ids:
		var grievance := _grievances.get_state(grievance_id)
		if grievance != null and grievance.phase == &"documented":
			evidence_strength += grievance.evidence_score
	var evidence := {}
	if evidence_strength > 0:
		evidence[&"fume_testimony"] = evidence_strength
	var worker_views := _organizing.worker_views()
	var participation := 0
	if not worker_views.is_empty():
		participation = int(round(100.0 * float(_organizing.forecast(ActionProposal.new(&"informal", &"", 50)).ready_count) / float(worker_views.size())))
	var negotiation_state := NegotiationState.new(
		evidence,
		int(_organizing.resources_snapshot().solidarity),
		participation,
		int(_organizing.resources_snapshot().treasury),
		int(_organizing.resources_snapshot().public_support),
		_worker_priorities()
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
	var grievance_views: Array[Dictionary] = []
	var sorted_ids := _grievance_ids.duplicate()
	sorted_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	for grievance_id in sorted_ids:
		var state := _grievances.get_state(grievance_id)
		if state == null:
			continue
		grievance_views.append({
			"id": state.id,
			"issue": state.issue,
			"affected_workers": state.affected_workers.duplicate(),
			"phase": state.phase,
			"evidence_score": state.evidence_score,
			"deadline_tick": state.deadline_tick,
		})
	return {
		"schema_version": SaveService.SCHEMA_VERSION,
		"seed": _seed,
		"chapter": &"bone_and_pick",
		"tick": _tick,
		"workday": _workday,
		"simulation": _simulation.snapshot(),
		"grievances": grievance_views,
		"resources": _organizing.resources_snapshot(),
		"last_strategy": _last_strategy,
		"negotiation": _last_negotiation.duplicate(true),
	}


func _advance_one_tick() -> EventDefinition:
	_simulation.apply_tick()
	_tick += 1
	_workday = int(_tick / TICKS_PER_WORKDAY) + 1
	_grievances.advance_deadlines(_tick)
	var snapshot := _simulation.snapshot()
	snapshot["active_issues"] = [&"cave_in_prevention", &"lantern_fume_exposure", &"maintenance_pay"]
	return _root.apply_fixed_tick(FixedTickEventCommand.new(_tick, _workday, snapshot))


func _worker_priorities() -> Dictionary:
	var workers := {}
	for worker in _organizing.worker_views():
		workers[StringName(worker.id)] = {
			"trust": int(worker.trust),
			"priorities": {&"safety": 3, &"schedule": 1, &"tool_maintenance": 1},
		}
	return workers


func _restore_durable(state: Dictionary) -> void:
	var target_tick := maxi(0, int(state.get("tick", 0)))
	for logical_tick in target_tick:
		var started := _advance_one_tick()
		if started != null:
			_root.complete_event(started.id)
	_workday = maxi(1, int(state.get("workday", _workday)))
	for grievance_view in state.get("grievances", []):
		var grievance_id := StringName(grievance_view.get("id", &""))
		var affected: Array[StringName] = []
		for worker_id in grievance_view.get("affected_workers", []):
			affected.append(StringName(worker_id))
		_grievances.report(IncidentRecord.new(grievance_id, StringName(grievance_view.get("issue", &"")), affected, 0))
		var evidence_score := int(grievance_view.get("evidence_score", 0))
		if evidence_score > 0:
			_grievances.add_evidence(grievance_id, EvidenceRecord.new(&"restored_evidence", evidence_score, int(grievance_view.get("deadline_tick", 0))))
		var grievance := _grievances.get_state(grievance_id)
		_organizing.register_grievance(grievance)
		_grievance_ids.append(grievance_id)
	_last_strategy = StringName(state.get("last_strategy", &""))
	if not _last_strategy.is_empty():
		negotiate_and_ratify(_last_strategy)
