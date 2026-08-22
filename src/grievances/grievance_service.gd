class_name GrievanceService
extends RefCounted

var _states: Dictionary[StringName, GrievanceState] = {}
var _order: Array[StringName] = []
var _current_tick := 0


static func restore(states: Array, current_tick: int = 0) -> GrievanceService:
	var service := GrievanceService.new()
	service._current_tick = maxi(0, current_tick)
	for raw_state in states:
		if not raw_state is Dictionary:
			continue
		var state := GrievanceState.from_dictionary(raw_state)
		if not state.id.is_empty():
			service._states[state.id] = state
			service._order.append(state.id)
	return service


func import_state(state: GrievanceState) -> bool:
	if state == null or state.id.is_empty() or _states.has(state.id):
		return false
	_order.append(state.id)
	_states[state.id] = state.snapshot()
	return true


func report(incident: IncidentRecord) -> StringName:
	if incident == null or incident.id.is_empty():
		return &""
	var grievance_id := incident.id
	if not _states.has(grievance_id):
		_states[grievance_id] = GrievanceState.new(grievance_id, incident.issue, incident.affected_workers)
		_order.append(grievance_id)
	return grievance_id


func get_state(grievance_id: StringName) -> GrievanceState:
	var state := _state_for(grievance_id)
	if state == null:
		return null
	return state.snapshot()


func add_evidence(grievance_id: StringName, evidence: EvidenceRecord) -> void:
	var state := _state_for(grievance_id)
	if state == null or evidence == null:
		return
	if evidence.deadline_tick > 0 and _current_tick > evidence.deadline_tick:
		state.expire(evidence.deadline_tick)
		return
	state.add_evidence(evidence)


func advance_deadlines(tick: int) -> void:
	_current_tick = maxi(_current_tick, tick)
	for state in _states.values():
		state.advance_deadline(_current_tick)


func resolve(grievance_id: StringName) -> bool:
	var state := _state_for(grievance_id)
	return state.resolve() if state != null else false


func transition_action(grievance_id: StringName, action: StringName) -> bool:
	var state := _state_for(grievance_id)
	return state.transition_action(action) if state != null else false


func snapshot() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for grievance_id in _order:
		views.append(_states[grievance_id].to_dictionary())
	return views


func _state_for(grievance_id: StringName) -> GrievanceState:
	if not _states.has(grievance_id):
		return null
	return _states[grievance_id]
