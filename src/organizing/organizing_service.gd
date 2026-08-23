class_name OrganizingService
extends RefCounted

const UnionResourcesScript = preload("res://src/organizing/union_resources.gd")
const ParticipationForecastScript = preload("res://src/organizing/participation_forecast.gd")
const ActionProposalScript = preload("res://src/organizing/action_proposal.gd")
const WorkerStateScript = preload("res://src/workers/worker_state.gd")
const GrievanceStateScript = preload("res://src/grievances/grievance_state.gd")

const EXECUTABLE_ACTIONS: Array[StringName] = [
	&"informal", &"grievance", &"petition", &"work_to_rule",
]
const LOCKED_ACTIONS: Array[StringName] = [&"walkout", &"strike"]
const UNCERTAINTY_MARGIN := 10
const RESOURCE_SPEND_ORDER: Array[StringName] = [
	&"treasury", &"solidarity", &"public_support", &"organizer_capacity",
]
const ACTION_COSTS: Dictionary[StringName, Dictionary] = {
	&"informal": {&"solidarity": 2},
	&"grievance": {&"solidarity": 1},
	&"petition": {&"solidarity": -2, &"public_support": 2},
	&"work_to_rule": {&"solidarity": -5, &"treasury": -5, &"public_support": -2},
}

var _workers: Dictionary[StringName, Dictionary] = {}
var _grievance_service: GrievanceService
var _resources: UnionResourcesScript


func _init(
	workers: Array = [],
	grievance_states: Array = [],
	resources: UnionResourcesScript = null,
	authoritative_grievances: GrievanceService = null
) -> void:
	_resources = UnionResourcesScript.new() if resources == null else _resources_from_snapshot(resources.snapshot())
	_grievance_service = GrievanceService.new() if authoritative_grievances == null else authoritative_grievances
	for worker in workers:
		if worker is WorkerStateScript:
			_register_worker_snapshot(worker as WorkerStateScript)
		elif worker is Dictionary:
			_register_worker_view(worker)
	for grievance in grievance_states:
		if grievance is GrievanceStateScript:
			register_grievance(grievance as GrievanceStateScript)
		elif grievance is Dictionary:
			register_grievance(GrievanceState.from_dictionary(grievance))


static func restore(worker_views: Array, grievance_views: Array, resources: Dictionary, authoritative_grievances: GrievanceService = null) -> OrganizingService:
	var grievance_service := GrievanceService.restore(grievance_views) if authoritative_grievances == null else authoritative_grievances
	return OrganizingService.new(worker_views, [], UnionResourcesScript.new(
		int(resources.get("solidarity", 0)),
		int(resources.get("treasury", 0)),
		int(resources.get("public_support", 0)),
		int(resources.get("organizer_capacity", 1))
	), grievance_service)


static func fixture_with_workers(
	consent_values: Array,
	resources: UnionResourcesScript = null
):
	var workers: Array[WorkerStateScript] = []
	for index in consent_values.size():
		var worker: WorkerStateScript = WorkerStateScript.new(StringName("worker_%d" % (index + 1)))
		var consent := int(consent_values[index])
		worker.trust = consent
		worker.action_willingness = consent
		workers.append(worker)
	return load("res://src/organizing/organizing_service.gd").new(workers, [], resources)


func register_grievance(grievance: GrievanceStateScript) -> bool:
	return _grievance_service.import_state(grievance)


func forecast(proposal: ActionProposalScript) -> ParticipationForecastScript:
	if proposal == null:
		return ParticipationForecastScript.new([], [], [], false, "proposal is required")
	var participation := _participation_for(proposal.participation_threshold)
	var blocker := _blocker_for(proposal, participation.ready_count)
	return ParticipationForecastScript.new(
		participation.ready_workers,
		participation.uncertain_workers,
		participation.unwilling_workers,
		blocker.is_empty(),
		blocker
	)


func execute(proposal: ActionProposalScript) -> Dictionary:
	var action_forecast := forecast(proposal)
	if not action_forecast.can_execute:
		return {
			"executed": false,
			"action": proposal.action if proposal != null else &"",
			"blocker": action_forecast.blocker,
			"ready_workers": action_forecast.ready_workers.duplicate(),
		}
	if not _grievance_service.transition_action(proposal.grievance_id, proposal.action):
		return {
			"executed": false,
			"action": proposal.action,
			"blocker": "grievance transition was rejected",
			"ready_workers": action_forecast.ready_workers.duplicate(),
		}
	for kind in RESOURCE_SPEND_ORDER:
		if ACTION_COSTS[proposal.action].has(kind):
			_resources.apply_delta(kind, int(ACTION_COSTS[proposal.action][kind]))
	return {
		"executed": true,
		"action": proposal.action,
		"blocker": "",
		"ready_workers": action_forecast.ready_workers.duplicate(),
	}


func apply_remedy(grievance_id: StringName, remedy_id: StringName) -> Dictionary:
	var grievance := _grievance_service.get_state(grievance_id)
	if grievance == null:
		return {"applied": false, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": "grievance does not exist: %s" % grievance_id}
	if remedy_id.is_empty():
		return {"applied": false, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": "remedy id is required"}
	if grievance.phase in GrievanceStateScript.TERMINAL_PHASES:
		return {"applied": false, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": "grievance is terminal: %s" % grievance.phase}
	if grievance.action_history.is_empty():
		return {"applied": false, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": "take an escalation step before applying a remedy"}
	if not _grievance_service.apply_remedy(grievance_id, remedy_id):
		return {"applied": false, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": "remedy transition was rejected"}
	return {"applied": true, "grievance_id": grievance_id, "remedy_id": remedy_id, "blocker": ""}


func resources_snapshot() -> Dictionary:
	return _resources.snapshot()


func worker_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for worker_id in _sorted_worker_ids():
		views.append(_workers[worker_id].duplicate(true))
	return views


func grievance_view(grievance_id: StringName) -> GrievanceStateScript:
	return _grievance_service.get_state(grievance_id)


func grievance_views() -> Array[Dictionary]:
	return _grievance_service.snapshot()


func synchronize_worker_views(views: Array) -> void:
	_workers.clear()
	for view in views:
		if view is Dictionary:
			_register_worker_view(view)


func _register_worker_snapshot(worker: WorkerStateScript) -> void:
	if worker == null:
		return
	var state: Dictionary = worker.snapshot()
	if state.id.is_empty():
		return
	_workers[state.id] = state.duplicate(true)


func _register_worker_view(state: Dictionary) -> void:
	var worker_id := StringName(state.get("id", &""))
	if not worker_id.is_empty():
		_workers[worker_id] = state.duplicate(true)


func _participation_for(threshold: int) -> ParticipationForecastScript:
	var ready: Array[StringName] = []
	var uncertain: Array[StringName] = []
	var unwilling: Array[StringName] = []
	for worker_id in _sorted_worker_ids():
		var worker := _workers[worker_id]
		if worker.employment_state != &"active":
			unwilling.append(worker_id)
			continue
		var consent := int((int(worker.trust) + int(worker.action_willingness)) / 2)
		if consent >= threshold:
			ready.append(worker_id)
		elif consent >= threshold - UNCERTAINTY_MARGIN:
			uncertain.append(worker_id)
		else:
			unwilling.append(worker_id)
	return ParticipationForecastScript.new(ready, uncertain, unwilling)


func _blocker_for(proposal: ActionProposalScript, ready_count: int) -> String:
	if LOCKED_ACTIONS.has(proposal.action):
		return "action is locked in this slice: %s" % proposal.action
	if not EXECUTABLE_ACTIONS.has(proposal.action):
		return "unknown action: %s" % proposal.action
	var grievance := _grievance_service.get_state(proposal.grievance_id)
	if grievance == null:
		return "requires a grievance: %s" % proposal.grievance_id
	var transition_blocker := grievance.action_blocker(proposal.action)
	if not transition_blocker.is_empty():
		return transition_blocker
	var required_ready := _required_ready_count(proposal.action)
	if ready_count < required_ready:
		return "requires at least %d ready workers" % required_ready
	return _resource_blocker_for(proposal.action)


func _required_ready_count(action: StringName) -> int:
	match action:
		&"petition":
			return 2
		&"work_to_rule":
			return (_workers.size() / 2) + 1
		_:
			return 1


func _resource_blocker_for(action: StringName) -> String:
	for kind in RESOURCE_SPEND_ORDER:
		var delta := int(ACTION_COSTS[action].get(kind, 0))
		if delta >= 0:
			continue
		var required := -delta
		var available := _resource_amount(kind)
		if available < required:
			return "requires %d %s, has %d" % [required, kind, available]
	return ""


func _resource_amount(kind: StringName) -> int:
	match kind:
		&"solidarity":
			return _resources.solidarity
		&"treasury":
			return _resources.treasury
		&"public_support":
			return _resources.public_support
		&"organizer_capacity":
			return _resources.organizer_capacity
	return 0


func _sorted_worker_ids() -> Array[StringName]:
	var worker_ids: Array[StringName] = _workers.keys()
	worker_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return worker_ids


func _resources_from_snapshot(state: Dictionary) -> UnionResourcesScript:
	return UnionResourcesScript.new(
		int(state.get("solidarity", 0)),
		int(state.get("treasury", 0)),
		int(state.get("public_support", 0)),
		int(state.get("organizer_capacity", 1))
	)
