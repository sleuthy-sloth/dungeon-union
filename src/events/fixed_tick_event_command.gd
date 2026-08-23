class_name FixedTickEventCommand
extends RefCounted

var _tick: int
var _workday: int
var _snapshot: Dictionary

var tick: int:
	get:
		return _tick

var workday: int:
	get:
		return _workday

var snapshot: Dictionary:
	get:
		return _snapshot.duplicate(true)


func _init(fixed_tick: int, workday_index: int, simulation_snapshot: Dictionary) -> void:
	_tick = maxi(0, fixed_tick)
	_workday = maxi(1, workday_index)
	_snapshot = simulation_snapshot.duplicate(true)
