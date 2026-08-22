class_name WorkerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var species: StringName
@export var job_id: StringName
@export var traits: Array[StringName]
@export var event_role_tags: Array[StringName]
@export_range(0, 100) var initial_trust := 50
@export_range(0, 100) var initial_action_willingness := 25
@export var bargaining_priorities: Dictionary[StringName, int] = {}
