class_name CampaignState
extends RefCounted

const BRANCHES: Array[StringName] = [
	&"steward_school",
	&"legal_desk",
	&"mutual_aid_kitchen",
	&"print_shop",
	&"organizing_workshop",
]

var _upgrade_points: int
var _upgrades: Array[StringName] = []


func _init(initial_upgrade_points: int = 5) -> void:
	_upgrade_points = maxi(0, initial_upgrade_points)


static func restore(view: Dictionary) -> CampaignState:
	var upgrades: Array = view.get("upgrades", [])
	var state := CampaignState.new(maxi(0, int(view.get("upgrade_points", 0))) + upgrades.size())
	for upgrade_id in upgrades:
		var text := String(upgrade_id)
		if text.ends_with("_1"):
			state.apply_command(ApplyUpgradeCommand.new(StringName(text.trim_suffix("_1")), 1))
	return state


func apply_command(command: ApplyUpgradeCommand) -> bool:
	if command == null or command.tier != 1 or not BRANCHES.has(command.branch):
		return false
	var upgrade_id := StringName("%s_1" % command.branch)
	if _upgrade_points <= 0 or _upgrades.has(upgrade_id):
		return false
	_upgrade_points -= 1
	_upgrades.append(upgrade_id)
	_upgrades.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return true


func read_view() -> Dictionary:
	return {
		"upgrade_points": _upgrade_points,
		"upgrades": _upgrades.duplicate(),
		"available_branches": BRANCHES.duplicate(),
	}
