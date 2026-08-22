class_name EvidenceRecord
extends RefCounted

var _source: StringName
var _reliability: int
var _deadline_tick: int

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


func _init(evidence_source: StringName, evidence_reliability: int, evidence_deadline_tick: int) -> void:
	_source = evidence_source
	_reliability = evidence_reliability
	_deadline_tick = evidence_deadline_tick
