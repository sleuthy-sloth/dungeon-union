class_name EvidenceRecord
extends RefCounted

var _id: StringName
var _kind: StringName
var _source: StringName
var _reliability: int
var _deadline_tick: int
var _relevant_issue: StringName

var id: StringName:
	get:
		return _id
	set(_value):
		pass

var kind: StringName:
	get:
		return _kind
	set(_value):
		pass

var source: StringName:
	get:
		return _source
	set(_value):
		pass

var reliability: int:
	get:
		return _reliability
	set(_value):
		pass

var deadline_tick: int:
	get:
		return _deadline_tick
	set(_value):
		pass

var relevant_issue: StringName:
	get:
		return _relevant_issue
	set(_value):
		pass


func _init(
	evidence_id: StringName,
	evidence_kind_or_reliability: Variant,
	evidence_source_or_deadline: Variant,
	evidence_reliability: int = 0,
	evidence_deadline_tick: int = 0,
	evidence_relevant_issue: StringName = &""
) -> void:
	_id = evidence_id
	if typeof(evidence_kind_or_reliability) in [TYPE_INT, TYPE_FLOAT]:
		# Compatibility for the original three-argument record boundary. Production
		# content uses the complete authored constructor below.
		_kind = evidence_id
		_source = evidence_id
		_reliability = maxi(0, int(evidence_kind_or_reliability))
		_deadline_tick = maxi(0, int(evidence_source_or_deadline))
		_relevant_issue = &""
	else:
		_kind = StringName(evidence_kind_or_reliability)
		_source = StringName(evidence_source_or_deadline)
		_reliability = maxi(0, evidence_reliability)
		_deadline_tick = maxi(0, evidence_deadline_tick)
		_relevant_issue = evidence_relevant_issue


func snapshot() -> EvidenceRecord:
	return EvidenceRecord.new(_id, _kind, _source, _reliability, _deadline_tick, _relevant_issue)


func to_dictionary() -> Dictionary:
	return {
		"id": _id,
		"kind": _kind,
		"source": _source,
		"reliability": _reliability,
		"deadline_tick": _deadline_tick,
		"relevant_issue": _relevant_issue,
	}


static func from_dictionary(view: Dictionary) -> EvidenceRecord:
	return EvidenceRecord.new(
		StringName(view.get("id", &"")),
		StringName(view.get("kind", &"")),
		StringName(view.get("source", &"")),
		maxi(0, int(view.get("reliability", 0))),
		maxi(0, int(view.get("deadline_tick", 0))),
		StringName(view.get("relevant_issue", &""))
	)
