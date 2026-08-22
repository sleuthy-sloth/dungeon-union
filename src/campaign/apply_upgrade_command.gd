class_name ApplyUpgradeCommand
extends RefCounted

var _branch: StringName
var _tier: int

var branch: StringName:
	get:
		return _branch

var tier: int:
	get:
		return _tier


func _init(upgrade_branch: StringName, upgrade_tier: int = 1) -> void:
	_branch = upgrade_branch
	_tier = upgrade_tier
