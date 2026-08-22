class_name UnionResources
extends RefCounted

const MAX_PERCENT := 100

var solidarity := 0
var treasury := 0
var public_support := 0
var organizer_capacity := 1


func _init(
	initial_solidarity: int = 0,
	initial_treasury: int = 0,
	initial_public_support: int = 0,
	initial_organizer_capacity: int = 1
) -> void:
	solidarity = clampi(initial_solidarity, 0, MAX_PERCENT)
	treasury = maxi(0, initial_treasury)
	public_support = clampi(initial_public_support, 0, MAX_PERCENT)
	organizer_capacity = maxi(0, initial_organizer_capacity)


func apply_delta(kind: StringName, amount: int) -> void:
	match kind:
		&"solidarity":
			solidarity = clampi(solidarity + amount, 0, MAX_PERCENT)
		&"treasury":
			treasury = maxi(0, treasury + amount)
		&"public_support":
			public_support = clampi(public_support + amount, 0, MAX_PERCENT)
		&"organizer_capacity":
			organizer_capacity = maxi(0, organizer_capacity + amount)


func snapshot() -> Dictionary:
	return {
		"solidarity": solidarity,
		"treasury": treasury,
		"public_support": public_support,
		"organizer_capacity": organizer_capacity,
	}
