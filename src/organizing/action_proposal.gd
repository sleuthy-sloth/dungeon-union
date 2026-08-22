class_name ActionProposal
extends RefCounted

var action: StringName
var grievance_id: StringName
var participation_threshold: int
var vote_authorized: bool


func _init(
	action_id: StringName,
	case_id: StringName = &"",
	threshold: int = 50,
	has_authorized_vote: bool = false
) -> void:
	action = action_id
	grievance_id = case_id
	participation_threshold = clampi(threshold, 0, 100)
	vote_authorized = has_authorized_vote
