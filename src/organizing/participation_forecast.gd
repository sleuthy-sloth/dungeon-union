class_name ParticipationForecast
extends RefCounted

var ready_workers: Array[StringName] = []
var uncertain_workers: Array[StringName] = []
var unwilling_workers: Array[StringName] = []
var can_execute := false
var blocker := ""

var ready_count: int:
	get:
		return ready_workers.size()


func _init(
	ready: Array[StringName] = [],
	uncertain: Array[StringName] = [],
	unwilling: Array[StringName] = [],
	can_take_action: bool = false,
	blocker_explanation: String = ""
) -> void:
	ready_workers = ready.duplicate()
	uncertain_workers = uncertain.duplicate()
	unwilling_workers = unwilling.duplicate()
	can_execute = can_take_action
	blocker = blocker_explanation
