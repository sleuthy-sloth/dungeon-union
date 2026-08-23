extends RefCounted

const BoneAndPickFixtureScript = preload("res://tests/fixtures/bone_and_pick_fixture.gd")


static func run(t: TestCase) -> void:
	var unprepared: Variant = BoneAndPickFixtureScript.new(771)
	var unprepared_result: Dictionary = unprepared.negotiate_and_ratify(&"safety_first")
	t.check(not unprepared_result.ratified, "a package without documented workplace evidence is rejected")
	var slice: Variant = BoneAndPickFixtureScript.new(771)
	slice.run_to_first_incident()
	t.equal(slice.active_workers().size(), 12, "slice has twelve active workers")
	t.check(slice.has_method("active_occurrence_view"), "fixture exposes the copied active authored occurrence")
	if not slice.has_method("active_occurrence_view"):
		return
	var active_occurrence: Dictionary = slice.active_occurrence_view()
	var before_mismatch: Dictionary = slice.durable_snapshot()
	var mismatch: Variant = slice.document_issue(&"unsafe_fumes")
	t.equal(mismatch, false, "fixture rejects a requested issue that does not match the active authored occurrence")
	t.equal(slice.durable_snapshot(), before_mismatch, "issue mismatch cannot mutate grievance, resources, or event state")
	t.check(slice.document_issue(StringName(active_occurrence.issue)), "fixture documents the actual active authored issue")
	var documented: Array = slice.durable_snapshot().grievances
	t.equal(documented.size(), 1, "actual authored occurrence creates exactly one grievance")
	if not documented.is_empty():
		t.equal(documented[0].id, active_occurrence.id, "documented grievance retains the authored occurrence identity")
		t.equal(documented[0].issue, active_occurrence.issue, "documented grievance retains the authored issue")
	slice.complete_workdays(3)
	var progressed: Dictionary = slice.durable_snapshot()
	t.check(progressed.has("incidents"), "fixture publishes production occurrence history instead of a private active-event shortcut")
	for grievance in progressed.grievances:
		t.equal(grievance.phase, &"resolved", "fixture closes intervening grievances through a public settlement")
		t.equal(grievance.action_history, [&"informal"], "fixture records the production informal escalation used before settlement")
		t.equal(grievance.resolved_action, &"fixture_settlement", "fixture records its explicit production remedy")
	if progressed.has("incidents"):
		for occurrence in progressed.incidents:
			if StringName(occurrence.event_kind) == EventDefinition.POSITIVE_KIND:
				t.equal(occurrence.completion, &"acknowledged", "fixture acknowledges intervening positive events through the public route")
	var result: Dictionary = slice.negotiate_and_ratify(&"safety_first")
	t.check(result.ratified, "prepared safety package ratifies")
	var restored: Variant = slice.save_and_restore()
	t.equal(restored.durable_snapshot(), slice.durable_snapshot(), "slice survives save round trip")
