class_name WorkerState
extends RefCounted

var id: StringName
var fatigue := 0
var trust := 50
var action_willingness := 25
var employment_state: StringName = &"active"


func _init(worker_id: StringName = &"") -> void:
	id = worker_id


func apply_work_tick(load: int) -> void:
	fatigue = clampi(fatigue + load, 0, 100)


func snapshot() -> Dictionary:
	return {
		"id": id,
		"fatigue": fatigue,
		"trust": trust,
		"action_willingness": action_willingness,
		"employment_state": employment_state,
	}
