class_name GrievanceState
extends RefCounted

const TERMINAL_PHASES: Array[StringName] = [&"resolved", &"expired", &"withdrawn"]
const DOCUMENTED_EVIDENCE_SCORE := 2

var id: StringName
var issue: StringName
var affected_workers: Array[StringName]
var phase: StringName = &"reported"
var evidence_score := 0
var deadline_tick := 0


func _init(
	grievance_id: StringName,
	grievance_issue: StringName,
	grievance_affected_workers: Array[StringName]
) -> void:
	id = grievance_id
	issue = grievance_issue
	affected_workers = grievance_affected_workers.duplicate()


func add_evidence(record: EvidenceRecord) -> void:
	if record == null or phase in TERMINAL_PHASES:
		return
	evidence_score += record.reliability
	if record.deadline_tick > 0 and (deadline_tick == 0 or record.deadline_tick < deadline_tick):
		deadline_tick = record.deadline_tick
	phase = &"documented" if evidence_score >= DOCUMENTED_EVIDENCE_SCORE else &"investigating"


func advance_deadline(tick: int) -> void:
	if phase in TERMINAL_PHASES or deadline_tick == 0:
		return
	if tick > deadline_tick:
		phase = &"expired"


func expire(deadline: int) -> void:
	if phase in TERMINAL_PHASES:
		return
	deadline_tick = deadline
	phase = &"expired"


func resolve() -> bool:
	if phase != &"documented":
		return false
	phase = &"resolved"
	return true


func snapshot() -> GrievanceState:
	var copied_state := GrievanceState.new(id, issue, affected_workers)
	copied_state.phase = phase
	copied_state.evidence_score = evidence_score
	copied_state.deadline_tick = deadline_tick
	return copied_state
