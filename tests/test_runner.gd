extends SceneTree

func _init() -> void:
    var t := TestCase.new()
    for script_path in [
        "res://tests/smoke/test_app_root.gd",
        "res://tests/content/test_content_validator.gd",
        "res://tests/simulation/test_deterministic_shift.gd",
        "res://tests/grievances/test_grievance_lifecycle.gd",
        "res://tests/organizing/test_escalation.gd",
        "res://tests/content/test_bone_and_pick_content.gd",
        "res://tests/events/test_event_pacing.gd",
        "res://tests/negotiation/test_bone_and_pick_contract.gd",
        "res://tests/save/test_save_round_trip.gd",
		"res://tests/acceptance/test_vertical_slice.gd",
		"res://tests/acceptance/test_workplace_presentation.gd",
    ]:
        load(script_path).run(t)
    for failure in t.failures:
        push_error(failure)
    quit(0 if t.failures.is_empty() else 1)
