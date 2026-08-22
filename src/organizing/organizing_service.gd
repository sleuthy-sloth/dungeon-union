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
const ACTION_COSTS: Dictionary[StringName, Dictionary] = {
	&"informal": {&"solidarity": 2},
	&"grievance": {&"solidarity": 1},
	&"petition": {&"solidarity": -2, &"public_support": 2},
	&"work_to_rule": {&"solidarity": -5, &"treasury": -5, &"public_support": -2},
}

var _workers: Dictionary[StringName, Dictionary] = {}
var _grievances: Dictionary[StringName, GrievanceStateScript] = {}
var _resources: UnionResourcesScript


func _init(
	workers: Array = [],
	grievance_states: Array = [],
	resources: UnionResourcesScript = null
) -> void:
	_resources = UnionResourcesScript.new() if resources == null else _resources_from_snapshot(resources.snapshot())
	for worker in workers:
		if worker is WorkerStateScript:
			_register_worker_snapshot(worker as WorkerStateScript)
	for grievance in grievance_states:
		if grievance is GrievanceStateScript:
			register_grievance(grievance as GrievanceStateScript)


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
	if grievance == null or grievance.id.is_empty():
		return false
	_grievances[grievance.id] = grievance.snapshot()
	return true


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
	for kind in ACTION_COSTS[proposal.action]:
		_resources.apply_delta(kind, int(ACTION_COSTS[proposal.action][kind]))
	return {
		"executed": true,
		"action": proposal.action,
		"blocker": "",
		"ready_workers": action_forecast.ready_workers.duplicate(),
	}


func resources_snapshot() -> Dictionary:
	return _resources.snapshot()


func _register_worker_snapshot(worker: WorkerStateScript) -> void:
	if worker == null:
		return
	var state: Dictionary = worker.snapshot()
	if state.id.is_empty():
		return
	_workers[state.id] = state.duplicate(true)


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
	if proposal.action != &"informal" and not _has_documented_grievance(proposal.grievance_id):
		return "requires a documented grievance: %s" % proposal.grievance_id
	var required_ready := _required_ready_count(proposal.action)
	if ready_count < required_ready:
		return "requires at least %d ready workers" % required_ready
	if proposal.action == &"work_to_rule" and _resources.treasury < 5:
		return "requires 5 treasury, has %d" % _resources.treasury
	return ""


func _has_documented_grievance(grievance_id: StringName) -> bool:
	return _grievances.has(grievance_id) and _grievances[grievance_id].phase == &"documented"


func _required_ready_count(action: StringName) -> int:
	match action:
		&"petition":
			return 2
		&"work_to_rule":
			return (_workers.size() / 2) + 1
		_:
			return 1


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
