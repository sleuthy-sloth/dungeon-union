extends RefCounted


static func run(t: TestCase) -> void:
	_major_event_gap_is_exactly_180_fixed_ticks(t)
	_one_active_major_event_blocks_another(t)
	_event_families_wait_two_workdays_before_repeating(t)
	_selection_is_deterministic_for_a_seed(t)
	_eligibility_is_a_pure_snapshot_query(t)


static func _major_event_gap_is_exactly_180_fixed_ticks(t: TestCase) -> void:
	var director := WorkplaceDirector.fixture(42)
	director.record_major_event(&"fume_leak", 100)
	t.equal(director.choose_next(200), null, "major event cooldown blocks overlap")
	t.equal(director.choose_next(279), null, "179 fixed ticks is still inside the 45-second gap")
	t.check(director.choose_next(280) != null, "eligible event resumes after 45 seconds")


static func _one_active_major_event_blocks_another(t: TestCase) -> void:
	var director := WorkplaceDirector.fixture(42)
	director.set_active_major_event(&"cave_in_risk")
	t.equal(director.choose_next(500), null, "one active major event blocks another major event")
	director.set_active_major_event(&"lantern_fumes")
	director.clear_active_major_event(&"lantern_fumes")
	t.equal(director.choose_next(500), null, "a second major event cannot replace the active major event")
	director.clear_active_major_event(&"cave_in_risk")
	t.check(director.choose_next(500) != null, "completing the active major event permits selection")


static func _event_families_wait_two_workdays_before_repeating(t: TestCase) -> void:
	var director := WorkplaceDirector.fixture(42)
	director.set_workday(1)
	director.record_major_event(&"cave_in_risk", 0)
	director.set_workday(2)
	var day_two := director.eligible_events(1000)
	t.check(not _has_family(day_two, &"cave_in_risk"), "a family cannot repeat on the next workday")
	director.set_workday(3)
	var day_three := director.eligible_events(1000)
	t.check(_has_family(day_three, &"cave_in_risk"), "a family becomes eligible after two workdays")


static func _selection_is_deterministic_for_a_seed(t: TestCase) -> void:
	var first := WorkplaceDirector.fixture(9917)
	var second := WorkplaceDirector.fixture(9917)

	for tick in [0, 180, 360]:
		var first_event: EventDefinition = first.choose_next(tick)
		var second_event: EventDefinition = second.choose_next(tick)
		t.equal(first_event.id, second_event.id, "matching seeds choose the same authored event")


static func _eligibility_is_a_pure_snapshot_query(t: TestCase) -> void:
	var event := EventDefinition.new()
	event.id = &"fume_leak"
	event.family = &"lantern_fumes"
	event.issue = &"safe_conditions"
	event.minimum_tick = 20
	event.required_worker_tags = [&"lantern_tender"]
	var engine := EventEngine.new([event])
	var snapshot := {
		"tick": 20,
		"active_issues": [&"safe_conditions"],
		"worker_tags": [&"lantern_tender"],
	}
	var before := snapshot.duplicate(true)

	t.equal(engine.eligible(snapshot), [event], "matching issue, tick, and role make an event eligible")
	t.equal(snapshot, before, "eligibility does not mutate the supplied simulation snapshot")
	snapshot.tick = 19
	t.equal(engine.eligible(snapshot), [], "minimum tick is inclusive and rejects earlier snapshots")
	snapshot.tick = 20
	snapshot.worker_tags = [&"hauler"]
	t.equal(engine.eligible(snapshot), [], "missing worker roles make an event ineligible")


static func _has_family(events: Array[EventDefinition], family: StringName) -> bool:
	for event in events:
		if event.family == family:
			return true
	return false
