class_name WorkerState
extends RefCounted

var id: StringName
var fatigue := 0
var trust := 50
var action_willingness := 25
var employment_state: StringName = &"active"
var bargaining_priorities: Dictionary[StringName, int] = {}


func _init(worker_id: StringName = &"") -> void:
	id = worker_id


static func from_definition(definition: WorkerDefinition) -> WorkerState:
	var state := WorkerState.new(definition.id)
	state.trust = definition.initial_trust
	state.action_willingness = definition.initial_action_willingness
	state.bargaining_priorities = definition.bargaining_priorities.duplicate(true)
	return state


static func from_view(view: Dictionary) -> WorkerState:
	var state := WorkerState.new(StringName(view.get("id", &"")))
	state.fatigue = clampi(int(view.get("fatigue", 0)), 0, 100)
	state.trust = clampi(int(view.get("trust", 50)), 0, 100)
	state.action_willingness = clampi(int(view.get("action_willingness", 25)), 0, 100)
	state.employment_state = StringName(view.get("employment_state", &"active"))
	var raw_priorities: Dictionary = view.get("bargaining_priorities", {})
	for issue in raw_priorities:
		state.bargaining_priorities[StringName(issue)] = maxi(0, int(raw_priorities[issue]))
	return state


func apply_work_tick(load: int) -> void:
	fatigue = clampi(fatigue + load, 0, 100)


func snapshot() -> Dictionary:
	return {
		"id": id,
		"fatigue": fatigue,
		"trust": trust,
		"action_willingness": action_willingness,
		"employment_state": employment_state,
		"bargaining_priorities": bargaining_priorities.duplicate(true),
	}
