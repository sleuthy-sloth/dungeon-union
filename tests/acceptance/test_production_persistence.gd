extends RefCounted

const Commands = preload("res://src/workplace/workplace_commands.gd")
const SAVE_PATH := "res://work/final_persistence/campaign.save"
const BOUNDARY_SAVE_PATH := "res://work/final_persistence/boundary.save"
const REJECTED_SAVE_PATH := "res://work/final_persistence/rejected.save"


static func run(t: TestCase) -> void:
	var command_script: GDScript = load("res://src/workplace/workplace_commands.gd")
	var controller_script: GDScript = load("res://src/workplace/workplace_controller.gd")
	var command_constants := command_script.get_script_constant_map()
	var controller_methods: Array[StringName] = []
	for method in controller_script.get_script_method_list():
		controller_methods.append(StringName(method.name))
	t.check(command_constants.has("ManualSaveCommand"), "playable controller exposes a typed manual-save command")
	t.check(command_constants.has("ManualLoadCommand"), "playable controller exposes a typed manual-load command")
	t.check(controller_methods.has(&"durable_snapshot"), "playable controller publishes its complete durable snapshot")
	t.check(controller_methods.has(&"restore_durable"), "playable controller exposes a public durable restore boundary")
	var app_probe := AppRoot.new()
	t.equal(app_probe.get("campaign_save_path"), "user://dungeon_union/campaign.save", "production orchestrator authors a user-data campaign path")
	app_probe.free()
	if not command_constants.has("ManualSaveCommand") or not command_constants.has("ManualLoadCommand") or not controller_methods.has(&"durable_snapshot") or not controller_methods.has(&"restore_durable"):
		return
	_controller_disk_round_trip_is_exact_and_deterministic(t, command_constants)
	_autosaves_and_startup_recovery_use_the_playable_orchestrator(t, command_constants)
	_rejected_ratification_autosaves_its_outcome(t)
	_shift_boundary_autosaves_survive_major_auto_pause(t)
	_cleanup()


static func _controller_disk_round_trip_is_exact_and_deterministic(t: TestCase, command_constants: Dictionary) -> void:
	_cleanup()
	var fixture := _runtime_fixture(SAVE_PATH, false, 904)
	var root: AppRoot = fixture.root
	var controller: WorkplaceController = fixture.controller
	controller.accessibility_settings.auto_pause_major_events = false
	controller.accessibility_settings.ui_scale = 1.5
	controller.accessibility_settings.high_contrast = true
	controller.advance_frame(0.25)
	var occurrence_id := StringName(controller.read_view().active_incidents[0].id)
	controller.apply_command(Commands.ProposeActionCommand.new(&"document", occurrence_id))
	controller.apply_command(Commands.ProposeActionCommand.new(&"informal", occurrence_id))
	var negotiation: Dictionary = controller.apply_command(Commands.EnterNegotiationCommand.new(&"safety_first"))
	t.check(negotiation.get("package", {}).has("_issued_agreement_id"), "production negotiation stores a resolver-issued tentative agreement")
	controller.advance_frame(0.125)
	var hall: UnionHallView = controller.get_node("UnionHallView")
	controller._open_union_hall()
	var install_button: Button = null
	for candidate in hall.find_children("*", "Button", true, false):
		if String(candidate.text).begins_with("INSTALL"):
			install_button = candidate
			break
	t.check(install_button != null, "scene fixture exposes a purchasable campaign upgrade")
	if install_button != null:
		install_button.pressed.emit()
	controller.apply_command(Commands.PauseCommand.new(false))

	var expected: Dictionary = controller.durable_snapshot()
	for key in [
		"seed", "tick", "workday", "clock", "simulation", "grievances", "resources",
		"incidents", "event_progress", "negotiation", "campaign", "accessibility",
	]:
		t.check(expected.has(key), "durable controller snapshot includes %s" % key)
	t.equal(expected.campaign.upgrades.size(), 1, "durable snapshot includes a purchased campaign upgrade")
	t.check(not expected.grievances[0].evidence_records.is_empty(), "durable snapshot includes authoritative evidence records")
	t.equal(expected.grievances[0].action_history, [&"informal"], "durable snapshot includes ordered grievance action history")
	t.check(not expected.negotiation.get("issued_agreement", {}).is_empty(), "durable snapshot includes the issued tentative agreement")
	t.check(expected.negotiation.has("ratification_outcome"), "durable snapshot includes the ratification outcome")

	var hud: WorkplaceHUD = controller.get_node("WorkplaceHUD")
	var save_button: Button = hud.find_child("ManualSaveAction", true, false)
	var load_button: Button = hud.find_child("ManualLoadAction", true, false)
	t.check(save_button != null and load_button != null, "HUD exposes visible manual Save and Load actions")
	if save_button != null:
		save_button.pressed.emit()
	else:
		controller.apply_command(command_constants.ManualSaveCommand.new())
	t.check(FileAccess.file_exists(SAVE_PATH), "manual Save action writes the injected disk path")

	var reference_fixture := _runtime_fixture("", false, 904)
	var reference: WorkplaceController = reference_fixture.controller
	t.check(reference.restore_durable(expected), "public restore accepts a complete controller snapshot")
	controller.apply_command(Commands.ApplyRemedyCommand.new(occurrence_id, &"temporary_mutation"))
	controller.accessibility_settings.ui_scale = 0.75
	controller.advance_frame(30.0)
	if load_button != null:
		load_button.pressed.emit()
	else:
		controller.apply_command(command_constants.ManualLoadCommand.new())
	t.equal(controller.durable_snapshot(), expected, "disk Load replaces mutations with the exact durable controller state")
	t.equal(controller.read_view().selected_incident_id, &"", "load rebuilds transient incident selection instead of serializing it")
	t.equal(controller.read_view().last_action_result.get("loaded", false), true, "manual Load publishes a player-visible acknowledgement")

	controller.advance_frame(30.125)
	reference.advance_frame(30.125)
	t.equal(controller.durable_snapshot(), reference.durable_snapshot(), "loaded simulation and event RNG continue deterministically from disk")

	controller.get_parent().remove_child(controller)
	controller.free()
	root.free()
	reference.get_parent().remove_child(reference)
	reference.free()
	reference_fixture.root.free()


static func _autosaves_and_startup_recovery_use_the_playable_orchestrator(t: TestCase, command_constants: Dictionary) -> void:
	_cleanup()
	var fixture := _runtime_fixture(SAVE_PATH, false, 113)
	var controller: WorkplaceController = fixture.controller
	controller.accessibility_settings.auto_pause_major_events = false
	t.check(FileAccess.file_exists(SAVE_PATH + ".autosave_0"), "configure writes the authored shift-start autosave")
	controller.advance_frame(60.0)
	for path in SaveService.new().autosave_paths(SAVE_PATH):
		t.check(FileAccess.file_exists(path), "shift-end and next-shift autosaves rotate through exactly three slots: %s" % path)
	var active: Array = controller.read_view().active_incidents
	if not active.is_empty():
		var occurrence_id := StringName(active[0].id)
		if StringName(active[0].event_kind) == EventDefinition.POSITIVE_KIND:
			controller.apply_command(Commands.AcknowledgeEventCommand.new(occurrence_id))
		else:
			controller.apply_command(Commands.ProposeActionCommand.new(&"document", occurrence_id))
	controller.apply_command(Commands.EnterNegotiationCommand.new(&"safety_first"))
	var newest_valid: Dictionary = controller.durable_snapshot()
	controller.apply_command(command_constants.ManualSaveCommand.new())
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt.store_var({"payload": {"schema_version": SaveService.SCHEMA_VERSION}, "checksum": "broken"})
	corrupt.close()
	controller.get_parent().remove_child(controller)
	controller.free()
	fixture.root.free()

	var tree: SceneTree = Engine.get_main_loop()
	var recovered_app: AppRoot = load("res://src/app/app_root.tscn").instantiate()
	recovered_app.event_seed = 113
	recovered_app.campaign_save_path = SAVE_PATH
	recovered_app.recover_campaign_on_startup = true
	tree.root.add_child(recovered_app)
	recovered_app.begin_shift(true)
	var recovered: WorkplaceController = recovered_app.get_node("WorkplaceView")
	t.equal(recovered.durable_snapshot(), newest_valid, "startup loads the newest valid autosave through the playable AppRoot/controller path")
	t.check(FileAccess.file_exists(SAVE_PATH + ".corrupt"), "startup recovery preserves the corrupt primary save")
	recovered_app.free()


static func _runtime_fixture(save_path: String, recover_existing: bool, seed: int) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop()
	var root := AppRoot.new()
	root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	root.event_seed = seed
	root.boot()
	var controller: WorkplaceController = load("res://src/workplace/workplace_view.tscn").instantiate()
	tree.root.add_child(controller)
	controller.call(&"configure", root, root.active_catalog, seed, save_path, recover_existing)
	return {"root": root, "controller": controller}


static func _shift_boundary_autosaves_survive_major_auto_pause(t: TestCase) -> void:
	_cleanup()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.event_role_tags = [&"hauler"]
	var event := EventDefinition.new()
	event.id = &"boundary_major"
	event.family = &"boundary_major"
	event.issue = &"cave_in_prevention"
	event.minimum_tick = WorkplaceController.TICKS_PER_WORKDAY
	event.major = true
	event.required_worker_tags = [&"hauler"]
	event.presentation_title = "Boundary major"
	event.presentation_description = "A major event begins exactly as the shift changes."
	event.visual_pattern = "!!!"
	event.evidence_kind = &"testimony"
	event.evidence_source = &"affected_worker"
	event.evidence_reliability = 2
	event.evidence_window_ticks = 960
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"boundary_workplace"
	workplace.worker_ids = [&"nib"]
	workplace.dispute_ids = [&"cave_in_prevention"]
	workplace.event_ids = [&"boundary_major"]
	var catalog := ContentCatalog.new()
	catalog.worker_items = [worker]
	catalog.event_items = [event]
	catalog.workplace_items = [workplace]
	var root := AppRoot.new()
	root.content_catalog = catalog
	root.event_seed = 9
	root.boot()
	var controller := WorkplaceController.new()
	controller.configure(root, root.active_catalog, 9, BOUNDARY_SAVE_PATH, false)
	controller.advance_frame(60.0)
	t.equal(controller.read_view().tick, WorkplaceController.TICKS_PER_WORKDAY, "major event auto-pauses on the exact shift boundary")
	t.check(controller.read_view().paused, "boundary fixture proves the major-event pause branch ran")
	for path in SaveService.new().autosave_paths(BOUNDARY_SAVE_PATH):
		t.check(FileAccess.file_exists(path), "shift-end/start autosave survives boundary auto-pause: %s" % path)
	controller.free()
	root.free()


static func _rejected_ratification_autosaves_its_outcome(t: TestCase) -> void:
	_cleanup()
	var fixture := _runtime_fixture(REJECTED_SAVE_PATH, false, 27)
	var controller: WorkplaceController = fixture.controller
	var vote: Dictionary = controller.apply_command(Commands.EnterNegotiationCommand.new(&"safety_first"))
	t.check(not vote.get("ratified", false), "unprepared fixture reaches a rejected ratification outcome")
	var expected: Dictionary = controller.durable_snapshot()
	var recovered := SaveService.new().load_campaign(REJECTED_SAVE_PATH)
	t.equal(recovered.get("negotiation", {}), expected.negotiation, "post-ratification autosave preserves a rejected vote as well as an accepted vote")
	controller.get_parent().remove_child(controller)
	controller.free()
	fixture.root.free()


static func _cleanup() -> void:
	var service := SaveService.new()
	var paths: Array[String] = []
	for base_path in [SAVE_PATH, BOUNDARY_SAVE_PATH, REJECTED_SAVE_PATH]:
		paths.append(base_path)
		paths.append(base_path + ".tmp")
		paths.append(base_path + ".corrupt")
		for autosave_path in service.autosave_paths(base_path):
			paths.append(autosave_path)
			paths.append(autosave_path + ".tmp")
			paths.append(autosave_path + ".corrupt")
	for path in paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://work/final_persistence"))
