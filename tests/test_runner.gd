extends SceneTree

func _initialize() -> void:
	# The production AppRoot keeps its user:// path. Tests that do not explicitly
	# inject a disk fixture avoid writing outside the repository sandbox.
	OS.set_environment("DUNGEON_UNION_SAVE_PATH", "disabled")
	call_deferred(&"_run_all")


func _run_all() -> void:
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
		"res://tests/acceptance/test_positive_event_routing.gd",
		"res://tests/acceptance/test_action_occurrences.gd",
		"res://tests/acceptance/test_authoritative_causality.gd",
		"res://tests/acceptance/test_scene_accessibility.gd",
		"res://tests/acceptance/test_durable_restoration.gd",
		"res://tests/acceptance/test_production_persistence.gd",
		"res://tests/acceptance/test_evidence_window_equivalence.gd",
		"res://tests/acceptance/test_keyboard_accessibility.gd",
		"res://tests/acceptance/test_environment_art.gd",
	]:
		if script_path in ["res://tests/acceptance/test_scene_accessibility.gd", "res://tests/acceptance/test_keyboard_accessibility.gd"]:
			await load(script_path).run(t)
		else:
			load(script_path).run(t)
	for failure in t.failures:
		push_error(failure)
	quit(0 if t.failures.is_empty() else 1)
