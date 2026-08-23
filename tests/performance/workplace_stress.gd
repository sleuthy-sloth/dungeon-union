extends SceneTree

const FIXTURE_PATH := "res://tests/performance/workplace_stress_fixture.gd"


func _init() -> void:
	var fixture_script: GDScript = load(FIXTURE_PATH)
	if fixture_script == null or not fixture_script.can_instantiate():
		push_error("workplace stress fixture has parse errors: %s" % FIXTURE_PATH)
		quit(1)
		return
	var fixture: Variant = fixture_script.new()
	var result: Dictionary = fixture.run()
	var errors: Array = result.get("errors", [])
	for message in errors:
		push_error(String(message))
	print("WORKPLACE_STRESS agents=%d ticks=%d elapsed_ms=%.3f backlog=%.6f" % [
		int(result.get("agents", 0)),
		int(result.get("ticks", 0)),
		float(result.get("elapsed_msec", 0.0)),
		float(result.get("backlog", 0.0)),
	])
	quit(1 if not errors.is_empty() else 0)
