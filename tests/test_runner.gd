extends SceneTree

func _init() -> void:
    var t := TestCase.new()
    for script_path in ["res://tests/smoke/test_app_root.gd"]:
        load(script_path).run(t)
    for failure in t.failures:
        push_error(failure)
    quit(0 if t.failures.is_empty() else 1)
