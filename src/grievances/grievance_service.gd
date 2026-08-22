class_name GrievanceService
extends RefCounted

var _states: Dictionary[StringName, GrievanceState] = {}
var _current_tick := 0


func report(incident: IncidentRecord) -> StringName:
	if incident == null or incident.id.is_empty():
		return &""
	var grievance_id := incident.id
	if not _states.has(grievance_id):
		_states[grievance_id] = GrievanceState.new(grievance_id, incident.issue, incident.affected_workers)
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


func _state_for(grievance_id: StringName) -> GrievanceState:
	if not _states.has(grievance_id):
		return null
	return _states[grievance_id]
