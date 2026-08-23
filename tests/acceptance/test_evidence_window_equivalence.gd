extends RefCounted

const Commands = preload("res://src/workplace/workplace_commands.gd")
const FixtureScript = preload("res://tests/fixtures/bone_and_pick_fixture.gd")


static func run(t: TestCase) -> void:
	var event_properties: Array[StringName] = []
	for property in EventDefinition.new().get_property_list():
		event_properties.append(StringName(property.name))
	t.check(event_properties.has(&"evidence_window_ticks"), "event content exposes a validated authored evidence window")
	var facade_probe: Variant = FixtureScript.new(771)
	var facade_has_production_clock: bool = facade_probe.has_method("advance_ticks")
	t.check(facade_has_production_clock, "vertical-slice facade advances through the production controller clock")
	if not event_properties.has(&"evidence_window_ticks") or not facade_has_production_clock:
		return
	_exact_boundary_matches_in_production_and_facade(t)


static func _exact_boundary_matches_in_production_and_facade(t: TestCase) -> void:
	var root := AppRoot.new()
	root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	root.event_seed = 771
	root.boot()
	var controller := WorkplaceController.new()
	controller.configure(root, root.active_catalog, 771)
	controller.accessibility_settings.auto_pause_major_events = false
	controller.advance_frame(0.25)
	var occurrence: Dictionary = controller.read_view().active_incidents[0]
	var occurrence_id := StringName(occurrence.id)
	var window_ticks := int(occurrence.get("evidence_window_ticks", 0))
	t.check(window_ticks > 3 * WorkplaceController.TICKS_PER_WORKDAY, "the authored first-case evidence window remains valid through three complete workdays")
	t.check(controller.apply_command(Commands.ProposeActionCommand.new(&"document", occurrence_id)).get("executed", false), "production controller documents the authored case")

	var facade: Variant = FixtureScript.new(771)
	facade.run_to_first_incident()
	var facade_occurrence: Dictionary = facade.active_occurrence_view()
	t.equal(facade_occurrence.get("evidence_window_ticks", 0), window_ticks, "facade receives the exact authored production evidence window")
	t.check(facade.document_issue(StringName(facade_occurrence.issue)), "facade documents through the production command path")

	var expected_deadline := int(controller.read_view().tick) + window_ticks
	var production_case := _case_view(controller.durable_snapshot().grievances, occurrence_id)
	var facade_case := _case_view(facade.durable_snapshot().grievances, StringName(facade_occurrence.id))
	t.equal(production_case.deadline_tick, expected_deadline, "production derives its deadline only from authored event lifetime")
	t.equal(facade_case.deadline_tick, expected_deadline, "facade derives the identical deadline from production orchestration")

	controller.advance_frame(float(window_ticks) * SimulationClock.TICK_SECONDS)
	facade.advance_ticks(window_ticks)
	production_case = _case_view(controller.durable_snapshot().grievances, occurrence_id)
	facade_case = _case_view(facade.durable_snapshot().grievances, StringName(facade_occurrence.id))
	t.equal(production_case.phase, &"documented", "the exact authored deadline tick remains valid in production")
	t.equal(facade_case.phase, &"documented", "the exact authored deadline tick remains valid in the facade")
	t.equal(facade.durable_snapshot().simulation, controller.durable_snapshot().simulation, "production and facade simulations remain identical at the evidence boundary")

	controller.advance_frame(SimulationClock.TICK_SECONDS)
	facade.advance_ticks(1)
	production_case = _case_view(controller.durable_snapshot().grievances, occurrence_id)
	facade_case = _case_view(facade.durable_snapshot().grievances, StringName(facade_occurrence.id))
	t.equal(production_case.phase, &"expired", "one tick beyond the authored lifetime expires the production case")
	t.equal(facade_case.phase, &"expired", "one tick beyond the authored lifetime expires the facade case")
	t.equal(facade_case, production_case, "overdue evidence state is exactly equivalent across production and facade")
	controller.free()
	root.free()


static func _case_view(grievances: Array, grievance_id: StringName) -> Dictionary:
	for grievance in grievances:
		if StringName(grievance.get("id", &"")) == grievance_id:
			return grievance.duplicate(true)
	return {}
