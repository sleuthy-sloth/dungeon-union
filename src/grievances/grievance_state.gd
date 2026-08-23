class_name GrievanceState
extends RefCounted

const TERMINAL_PHASES: Array[StringName] = [&"resolved", &"expired", &"withdrawn"]
const DOCUMENTED_EVIDENCE_SCORE := 2
const ACTION_SEQUENCE: Array[StringName] = [&"informal", &"grievance", &"petition", &"work_to_rule"]

var id: StringName
var issue: StringName
var affected_workers: Array[StringName]
var phase: StringName = &"reported"
var evidence_score := 0
var evidence_records: Array[EvidenceRecord] = []
var deadline_tick := 0
var resolved_action: StringName = &""
var action_history: Array[StringName] = []


func _init(
	grievance_id: StringName,
	grievance_issue: StringName,
	grievance_affected_workers: Array[StringName]
) -> void:
	id = grievance_id
	issue = grievance_issue
	affected_workers = grievance_affected_workers.duplicate()


func add_evidence(record: EvidenceRecord) -> void:
	if record == null or record.id.is_empty() or phase in TERMINAL_PHASES:
		return
	for existing in evidence_records:
		if existing.id == record.id:
			return
	evidence_records.append(record.snapshot())
	evidence_score += record.reliability
	if record.deadline_tick > 0 and (deadline_tick == 0 or record.deadline_tick < deadline_tick):
		deadline_tick = record.deadline_tick
	if phase in [&"reported", &"investigating", &"documented"]:
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
	return apply_remedy(&"settlement")


func transition_action(action: StringName) -> bool:
	if not action_blocker(action).is_empty():
		return false
	action_history.append(action)
	match action:
		&"grievance":
			phase = &"submitted"
		&"petition", &"work_to_rule":
			phase = &"escalated"
	return true


func action_blocker(action: StringName) -> String:
	if phase in TERMINAL_PHASES:
		return "grievance is terminal: %s" % phase
	if not ACTION_SEQUENCE.has(action):
		return "unknown action: %s" % action
	if action_history.size() >= ACTION_SEQUENCE.size():
		return "all slice escalation steps are complete; apply a remedy"
	var expected := ACTION_SEQUENCE[action_history.size()]
	if action != expected:
		return "next escalation step is %s" % expected
	match action:
		&"informal":
			if phase not in [&"reported", &"investigating", &"documented"]:
				return "informal action requires an open reported case"
		&"grievance":
			if phase != &"documented":
				return "formal grievance requires documented evidence"
		&"petition":
			if phase != &"submitted":
				return "petition requires a submitted grievance"
		&"work_to_rule":
			if phase != &"escalated":
				return "work-to-rule requires an escalated petition"
	return ""


func apply_remedy(remedy_id: StringName) -> bool:
	if remedy_id.is_empty() or phase in TERMINAL_PHASES or action_history.is_empty():
		return false
	phase = &"resolved"
	resolved_action = remedy_id
	return true


func snapshot() -> GrievanceState:
	var copied_state := GrievanceState.new(id, issue, affected_workers)
	copied_state.phase = phase
	copied_state.evidence_score = evidence_score
	for record in evidence_records:
		copied_state.evidence_records.append(record.snapshot())
	copied_state.deadline_tick = deadline_tick
	copied_state.resolved_action = resolved_action
	copied_state.action_history = action_history.duplicate()
	return copied_state


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"issue": issue,
		"affected_workers": affected_workers.duplicate(),
		"phase": phase,
		"evidence_score": evidence_score,
		"evidence_records": evidence_records.map(func(record: EvidenceRecord) -> Dictionary: return record.to_dictionary()),
		"deadline_tick": deadline_tick,
		"resolved_action": resolved_action,
		"action_history": action_history.duplicate(),
	}


static func from_dictionary(view: Dictionary) -> GrievanceState:
	var affected: Array[StringName] = []
	for worker_id in view.get("affected_workers", []):
		affected.append(StringName(worker_id))
	var state := GrievanceState.new(StringName(view.get("id", &"")), StringName(view.get("issue", &"")), affected)
	state.phase = StringName(view.get("phase", &"reported"))
	state.evidence_score = maxi(0, int(view.get("evidence_score", 0)))
	for raw_record in view.get("evidence_records", []):
		if raw_record is Dictionary:
			var record := EvidenceRecord.from_dictionary(raw_record)
			if not record.id.is_empty():
				state.evidence_records.append(record)
	state.deadline_tick = maxi(0, int(view.get("deadline_tick", 0)))
	state.resolved_action = StringName(view.get("resolved_action", &""))
	for action in view.get("action_history", []):
		var action_id := StringName(action)
		if ACTION_SEQUENCE.has(action_id):
			state.action_history.append(action_id)
	return state
