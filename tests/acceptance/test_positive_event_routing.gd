extends RefCounted

const Commands = preload("res://src/workplace/workplace_commands.gd")


static func run(t: TestCase) -> void:
	var event_properties: Array[StringName] = []
	var probe := EventDefinition.new()
	for property in probe.get_property_list():
		event_properties.append(StringName(property.name))
	for required in [&"event_kind", &"presentation_title", &"presentation_description", &"visual_pattern"]:
		t.check(event_properties.has(required), "authored event exposes %s" % required)
	if not event_properties.has(&"event_kind"):
		return
	var command_script: GDScript = load("res://src/workplace/workplace_commands.gd")
	var command_constants := command_script.get_script_constant_map()
	t.check(command_constants.has("AcknowledgeEventCommand"), "positive completion uses a typed acknowledgement command")
	if not command_constants.has("AcknowledgeEventCommand"):
		return
	_positive_hud_never_labels_mutual_aid_as_a_grievance(t)
	var fixture := _positive_then_major_controller()
	var root: AppRoot = fixture.root
	var controller: WorkplaceController = fixture.controller
	controller.advance_frame(0.25)
	var positive_view: Dictionary = controller.read_view()
	t.equal(positive_view.active_incidents.size(), 1, "positive authored occurrence is player-visible")
	if positive_view.active_incidents.is_empty():
		controller.free()
		root.free()
		return
	var positive: Dictionary = positive_view.active_incidents[0]
	var positive_id := StringName(positive.id)
	t.equal(positive.event_kind, &"positive", "positive occurrence keeps its authored classification")
	t.equal(positive.title, "Crew shares the load", "positive occurrence copies its authored title")
	t.equal(positive.description, "Nib and Brakka redistribute the heaviest baskets.", "positive occurrence copies its authored description")
	t.equal(positive.pattern, "+++ / mutual aid", "positive occurrence copies its authored visual pattern")
	t.check(not positive.has("grievance_phase") and not positive.has("evidence_score"), "positive occurrence never becomes a grievance view")
	t.equal(positive_view.action_forecasts, {}, "positive occurrence never enters grievance forecasts")
	var resources_before: Dictionary = positive_view.resources
	var rejected: Dictionary = controller.apply_command(Commands.ProposeActionCommand.new(&"document", positive_id))
	t.check(not rejected.get("executed", false), "grievance actions reject a positive occurrence")
	t.equal(controller.read_view().resources, resources_before, "positive occurrence cannot manufacture organizing resources")

	controller.advance_frame(0.25)
	var concurrent: Dictionary = controller.read_view()
	t.equal(concurrent.active_incidents.size(), 2, "unacknowledged positive occurrence does not block a later major event")
	t.check(_contains_runtime(concurrent.active_incidents, &"later_major"), "the later grievance major starts beside mutual aid")
	var acknowledgement: Dictionary = controller.apply_command(
		command_constants.AcknowledgeEventCommand.new(positive_id)
	)
	t.check(acknowledgement.get("acknowledged", false), "player can acknowledge the positive occurrence through its typed command")
	var completed: Dictionary = controller.read_view()
	t.check(not _contains_occurrence(completed.active_incidents, positive_id), "acknowledged positive occurrence leaves the active list")
	t.check(_contains_occurrence(completed.incident_history, positive_id), "acknowledged positive occurrence remains in player-visible history")
	var historical := _occurrence(completed.incident_history, positive_id)
	t.equal(historical.get("completion", &""), &"acknowledged", "positive history records its explicit completion")
	t.check(not root.event_progress_view().active_event_ids.has(&"positive_aid"), "acknowledgement completes the positive runtime")
	t.check(root.event_progress_view().active_event_ids.has(&"later_major"), "acknowledgement does not complete the unrelated major runtime")
	t.equal(completed.resources, resources_before, "acknowledgement has no evidence or bargaining resource side effects")
	controller.free()
	root.free()


static func _positive_hud_never_labels_mutual_aid_as_a_grievance(t: TestCase) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var hud := WorkplaceHUD.new()
	tree.root.add_child(hud)
	var occurrence := {
		"id": &"positive_aid@00000001",
		"event_kind": EventDefinition.POSITIVE_KIND,
		"title": "Crew shares the load",
		"description": "Nib and Brakka redistribute the heaviest baskets.",
		"affected_workers": [&"nib", &"brakka"],
		"pattern": "+++ / mutual aid",
		"completion": &"active",
	}
	hud.update_view({
		"workers": [],
		"active_incidents": [occurrence],
		"incidents": [occurrence],
		"incident_history": [],
		"selected_incident_id": occurrence.id,
		"action_forecasts": {},
	})
	var incident_button := hud.incident_button(occurrence.id)
	t.check(incident_button != null and String(incident_button.text).begins_with("✦"), "HUD labels mutual aid with its positive-event glyph")
	t.check(incident_button != null and String(incident_button.text).contains("ACTIVE"), "HUD labels mutual aid active instead of reported as a grievance")
	t.equal(hud.find_child("DocumentAction", true, false).text, "ACKNOWLEDGE EVENT", "HUD exposes the player-visible positive acknowledgement action")

	var acknowledged := occurrence.duplicate(true)
	acknowledged["completion"] = &"acknowledged"
	hud.update_view({
		"workers": [],
		"active_incidents": [],
		"incidents": [],
		"incident_history": [acknowledged],
		"selected_incident_id": &"",
		"action_forecasts": {},
	})
	var history_label: Label = hud.find_child("ActionResult", true, false)
	t.check(history_label != null and String(history_label.text).contains("Crew shares the load"), "acknowledged mutual aid remains in persistent player-visible HUD history")
	t.check(history_label != null and String(history_label.text).contains("ACKNOWLEDGED"), "HUD history names the positive completion state")
	hud.free()


static func _positive_then_major_controller() -> Dictionary:
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.display_name = "Nib"
	worker.event_role_tags = [&"hauler"]
	var positive := EventDefinition.new()
	positive.id = &"positive_aid"
	positive.family = &"spontaneous_mutual_aid"
	positive.event_kind = &"positive"
	positive.minimum_tick = 1
	positive.major = false
	positive.required_worker_tags = [&"hauler"]
	positive.presentation_title = "Crew shares the load"
	positive.presentation_description = "Nib and Brakka redistribute the heaviest baskets."
	positive.visual_pattern = "+++ / mutual aid"
	var later_major := EventDefinition.new()
	later_major.id = &"later_major"
	later_major.family = &"cave_in_risk"
	later_major.event_kind = &"grievance"
	later_major.issue = &"cave_in_prevention"
	later_major.minimum_tick = 2
	later_major.major = true
	later_major.required_worker_tags = [&"hauler"]
	later_major.presentation_title = "Loose shoring"
	later_major.presentation_description = "The west face needs inspection."
	later_major.visual_pattern = "XXX / unstable stone"
	later_major.evidence_kind = &"shoring_testimony"
	later_major.evidence_source = &"affected_worker"
	later_major.evidence_reliability = 2
	later_major.evidence_window_ticks = 960
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"positive_route_fixture"
	workplace.worker_ids = [&"nib"]
	workplace.dispute_ids = [&"cave_in_prevention"]
	workplace.event_ids = [&"positive_aid", &"later_major"]
	var catalog := ContentCatalog.new()
	catalog.worker_items = [worker]
	catalog.workplace_items = [workplace]
	catalog.event_items = [positive, later_major]
	var root := AppRoot.new()
	root.content_catalog = catalog
	root.boot()
	var controller := WorkplaceController.new()
	controller.configure(root, root.active_catalog, 771)
	controller.accessibility_settings.auto_pause_major_events = false
	return {"root": root, "controller": controller}


static func _contains_runtime(items: Array, runtime_id: StringName) -> bool:
	for item in items:
		if StringName(item.get("runtime_id", &"")) == runtime_id:
			return true
	return false


static func _contains_occurrence(items: Array, occurrence_id: StringName) -> bool:
	return not _occurrence(items, occurrence_id).is_empty()


static func _occurrence(items: Array, occurrence_id: StringName) -> Dictionary:
	for item in items:
		if StringName(item.get("id", &"")) == occurrence_id:
			return item
	return {}
