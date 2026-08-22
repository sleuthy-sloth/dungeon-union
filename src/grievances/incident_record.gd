class_name IncidentRecord
extends RefCounted

var _id: StringName
var _issue: StringName
var _affected_workers: Array[StringName]
var _tick: int

var id: StringName:
	get:
		return _id
	set(_value):
		pass

var issue: StringName:
	get:
		return _issue
	set(_value):
		pass

var affected_workers: Array[StringName]:
	get:
		return _affected_workers.duplicate()
	set(_value):
		pass

var tick: int:
	get:
		return _tick
	set(_value):
		pass


func _init(
	incident_id: StringName,
	incident_issue: StringName,
	incident_affected_workers: Array[StringName],
	incident_tick: int
) -> void:
	_id = incident_id
	_issue = incident_issue
	_affected_workers = incident_affected_workers.duplicate()
	_tick = incident_tick
