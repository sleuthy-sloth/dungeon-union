class_name WorkplaceCommands
extends RefCounted


class SelectWorkerCommand extends RefCounted:
	var worker_id: StringName

	func _init(selected_worker_id: StringName) -> void:
		worker_id = selected_worker_id


class InspectIncidentCommand extends RefCounted:
	var incident_id: StringName

	func _init(selected_incident_id: StringName) -> void:
		incident_id = selected_incident_id


class AcknowledgeEventCommand extends RefCounted:
	var occurrence_id: StringName

	func _init(event_occurrence_id: StringName) -> void:
		occurrence_id = event_occurrence_id


class PauseCommand extends RefCounted:
	var paused: bool

	func _init(should_pause: bool) -> void:
		paused = should_pause


class SetSpeedCommand extends RefCounted:
	var speed: int

	func _init(next_speed: int) -> void:
		speed = next_speed


class ProposeActionCommand extends RefCounted:
	var action: StringName
	var grievance_id: StringName

	func _init(action_id: StringName, case_id: StringName) -> void:
		action = action_id
		grievance_id = case_id


class ApplyRemedyCommand extends RefCounted:
	var grievance_id: StringName
	var remedy_id: StringName

	func _init(case_id: StringName, settlement_id: StringName = &"settlement") -> void:
		grievance_id = case_id
		remedy_id = settlement_id


class EnterNegotiationCommand extends RefCounted:
	var strategy: StringName

	func _init(selected_strategy: StringName = &"safety_first") -> void:
		strategy = selected_strategy


class ManualSaveCommand extends RefCounted:
	pass


class ManualLoadCommand extends RefCounted:
	pass
