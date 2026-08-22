extends RefCounted

const Commands = preload("res://src/workplace/workplace_commands.gd")


static func run(t: TestCase) -> void:
	_informal_resolution_does_not_manufacture_evidence(t)
	_all_actions_are_idempotent_and_atomic(t)
	_occurrences_have_unique_identity_and_active_history_views(t)


static func _informed_controller() -> Dictionary:
	var root := AppRoot.new()
	root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	root.boot()
	var controller := WorkplaceController.new()
	controller.configure(root, root.active_catalog, 771)
	controller.accessibility_settings.auto_pause_major_events = false
	controller.advance_frame(0.25)
	return {"root": root, "controller": controller}


static func _informed_action_fixture(action: StringName) -> Dictionary:
	var fixture := _informed_controller()
	var controller: WorkplaceController = fixture.controller
	var occurrence_id := StringName(controller.read_view().incidents[0].id)
	if action != &"informal":
		controller.apply_command(Commands.ProposeActionCommand.new(&"document", occurrence_id))
	fixture["occurrence_id"] = occurrence_id
	return fixture


static func _informal_resolution_does_not_manufacture_evidence(t: TestCase) -> void:
	var fixture := _informed_action_fixture(&"informal")
	var controller: WorkplaceController = fixture.controller
	var result := controller.apply_command(Commands.ProposeActionCommand.new(&"informal", fixture.occurrence_id))
	var incident: Dictionary = controller.read_view().incident_history[0] if not controller.read_view().get("incident_history", []).is_empty() else controller.read_view().incidents[0]
	t.check(result.get("executed", false), "informal resolution executes from a reported grievance")
	t.equal(incident.get("evidence_score", -1), 0, "informal resolution does not invent testimony")
	t.equal(incident.get("resolved_action", &""), &"informal", "grievance records the action-aware informal transition")
	controller.free()
	fixture.root.free()


static func _all_actions_are_idempotent_and_atomic(t: TestCase) -> void:
	for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
		var fixture := _informed_action_fixture(action)
		var controller: WorkplaceController = fixture.controller
		var occurrence_id: StringName = fixture.occurrence_id
		var before: Dictionary = controller.read_view().resources
		var first := controller.apply_command(Commands.ProposeActionCommand.new(action, occurrence_id))
		t.check(first.get("executed", false), "%s commits once" % action)
		var after_first: Dictionary = controller.read_view().resources
		t.check(after_first != before, "%s applies its resource effect" % action)
		var negotiation_after_first := controller.apply_command(Commands.EnterNegotiationCommand.new(&"safety_first"))
		if action == &"informal":
			t.check(not negotiation_after_first.ratified, "evidence-free informal resolution cannot manufacture a ratified package")
		var repeated := controller.apply_command(Commands.ProposeActionCommand.new(action, occurrence_id))
		t.check(not repeated.get("executed", false), "%s terminal repeat is rejected" % action)
		t.equal(controller.read_view().resources, after_first, "%s repeat cannot change resources" % action)
		t.equal(controller.apply_command(Commands.EnterNegotiationCommand.new(&"safety_first")).ratified, negotiation_after_first.ratified, "%s repeat cannot flip negotiation" % action)
		controller.free()
		fixture.root.free()


static func _occurrences_have_unique_identity_and_active_history_views(t: TestCase) -> void:
	var fixture := _informed_action_fixture(&"informal")
	var controller: WorkplaceController = fixture.controller
	var first_id: StringName = fixture.occurrence_id
	var first_view := controller.read_view()
	t.check(first_view.has("active_incidents") and first_view.has("incident_history"), "workplace separates active incidents from history")
	controller.apply_command(Commands.ProposeActionCommand.new(&"informal", first_id))
	var same_family: Array[Dictionary] = []
	for logical_tick in 5000:
		controller.advance_frame(0.25)
		for incident in controller.read_view().get("active_incidents", []):
			if incident.get("definition_id", &"") == &"cave_in_risk":
				same_family.append(incident)
				break
			controller.apply_command(Commands.ProposeActionCommand.new(&"informal", StringName(incident.id)))
		if not same_family.is_empty():
			break
	t.check(not same_family.is_empty(), "same event family can recur after two workdays")
	if not same_family.is_empty():
		var second_id := StringName(same_family[0].id)
		t.check(second_id != first_id, "recurring event receives a unique occurrence id")
		t.equal(same_family[0].get("runtime_id", &""), &"cave_in_risk", "occurrence retains the runtime definition id")
		controller.apply_command(Commands.ProposeActionCommand.new(&"document", second_id))
		t.check(controller.apply_command(Commands.ProposeActionCommand.new(&"grievance", second_id)).get("executed", false), "second occurrence is independently documentable and resolvable")
		controller.advance_frame(121.0)
		t.check(not controller.read_view().get("active_incidents", []).is_empty(), "resolving recurrence does not leave the director blocked")
	controller.free()
	fixture.root.free()
