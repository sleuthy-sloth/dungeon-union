extends RefCounted


static func run(t: TestCase) -> void:
	_atomic_start_routes_major_lifecycle_and_exact_cooldown(t)
	_event_families_wait_two_workdays_before_repeating_for_minor_events(t)
	_selection_is_deterministic_for_a_seed(t)
	_eligibility_is_a_pure_snapshot_query(t)


static func _atomic_start_routes_major_lifecycle_and_exact_cooldown(t: TestCase) -> void:
	var director := WorkplaceDirector.fixture(42)
	var started: EventDefinition = director.choose_and_start(100)
	t.check(started != null, "an eligible authored event starts atomically")
	t.equal(director.choose_and_start(280), null, "an active major event blocks another start")
	t.check(not director.complete_event(&"different_event"), "non-matching completion cannot clear the active major event")
	t.equal(director.choose_and_start(280), null, "a mismatched completion leaves the major event active")
	t.check(director.complete_event(started.id), "matching completion routes the major event lifecycle")
	t.equal(director.choose_and_start(279), null, "179 fixed ticks is still inside the 45-second gap")
	t.check(director.choose_and_start(280) != null, "eligible event resumes at the exact 180-tick boundary")


static func _event_families_wait_two_workdays_before_repeating_for_minor_events(t: TestCase) -> void:
	var minor := EventDefinition.new()
	minor.id = &"mutual_aid"
	minor.family = &"spontaneous_mutual_aid"
	minor.major = false
	var director := WorkplaceDirector.new([minor], 42)
	director.set_workday(1)
	t.equal(director.choose_and_start(0), minor, "minor event starts and records its family")
	director.set_workday(2)
	var day_two := director.eligible_events(1000)
	t.check(not _has_family(day_two, &"spontaneous_mutual_aid"), "a minor family cannot repeat on the next workday")
	director.set_workday(3)
	var day_three := director.eligible_events(1000)
	t.check(_has_family(day_three, &"spontaneous_mutual_aid"), "a minor family becomes eligible after two workdays")


static func _selection_is_deterministic_for_a_seed(t: TestCase) -> void:
	var first := WorkplaceDirector.fixture(9917)
	var second := WorkplaceDirector.fixture(9917)

	for tick in [0, 180, 360]:
		var first_event: EventDefinition = first.choose_and_start(tick)
		var second_event: EventDefinition = second.choose_and_start(tick)
		t.equal(first_event.id, second_event.id, "matching seeds choose the same authored event")
		first.complete_event(first_event.id)
		second.complete_event(second_event.id)


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
