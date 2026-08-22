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
var resolved_action: StringName = &""


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
	return transition_action(&"grievance")


func transition_action(action: StringName) -> bool:
	if phase in TERMINAL_PHASES:
		return false
	if action == &"informal":
		if phase not in [&"reported", &"investigating", &"documented"]:
			return false
	elif action in [&"grievance", &"petition", &"work_to_rule"]:
		if phase != &"documented":
			return false
	else:
		return false
	phase = &"resolved"
	resolved_action = action
	return true


func snapshot() -> GrievanceState:
	var copied_state := GrievanceState.new(id, issue, affected_workers)
	copied_state.phase = phase
	copied_state.evidence_score = evidence_score
	copied_state.deadline_tick = deadline_tick
	copied_state.resolved_action = resolved_action
	return copied_state


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"issue": issue,
		"affected_workers": affected_workers.duplicate(),
		"phase": phase,
		"evidence_score": evidence_score,
		"deadline_tick": deadline_tick,
		"resolved_action": resolved_action,
	}


static func from_dictionary(view: Dictionary) -> GrievanceState:
	var affected: Array[StringName] = []
	for worker_id in view.get("affected_workers", []):
		affected.append(StringName(worker_id))
	var state := GrievanceState.new(StringName(view.get("id", &"")), StringName(view.get("issue", &"")), affected)
	state.phase = StringName(view.get("phase", &"reported"))
	state.evidence_score = maxi(0, int(view.get("evidence_score", 0)))
	state.deadline_tick = maxi(0, int(view.get("deadline_tick", 0)))
	state.resolved_action = StringName(view.get("resolved_action", &""))
	return state
