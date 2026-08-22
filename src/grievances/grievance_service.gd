class_name GrievanceService
extends RefCounted

var _states: Dictionary[StringName, GrievanceState] = {}


func report(incident: IncidentRecord) -> StringName:
	if incident == null or incident.id.is_empty():
		return &""
	var grievance_id := incident.id
	if not _states.has(grievance_id):
		_states[grievance_id] = GrievanceState.new(grievance_id, incident)
	return grievance_id


func get_state(grievance_id: StringName) -> GrievanceState:
	if not _states.has(grievance_id):
		return null
	return _states[grievance_id]


func add_evidence(grievance_id: StringName, evidence: EvidenceRecord) -> void:
	var state := get_state(grievance_id)
	if state == null:
		return
	state.add_evidence(evidence)


func advance_deadlines(tick: int) -> void:
	for state in _states.values():
		state.advance_deadline(tick)
