extends RefCounted

const BoneAndPickFixtureScript = preload("res://tests/fixtures/bone_and_pick_fixture.gd")


static func run(t: TestCase) -> void:
	var unprepared: Variant = BoneAndPickFixtureScript.new(771)
	var unprepared_result: Dictionary = unprepared.negotiate_and_ratify(&"safety_first")
	t.check(not unprepared_result.ratified, "a package without documented workplace evidence is rejected")
	var slice: Variant = BoneAndPickFixtureScript.new(771)
	slice.run_to_first_incident()
	t.equal(slice.active_workers().size(), 12, "slice has twelve active workers")
	slice.document_issue(&"unsafe_fumes")
	slice.complete_workdays(3)
	var result: Dictionary = slice.negotiate_and_ratify(&"safety_first")
	t.check(result.ratified, "prepared safety package ratifies")
	var restored: Variant = slice.save_and_restore()
	t.equal(restored.durable_snapshot(), slice.durable_snapshot(), "slice survives save round trip")
