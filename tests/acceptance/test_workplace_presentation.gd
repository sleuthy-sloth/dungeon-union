extends RefCounted


class RecordingAppRoot extends AppRoot:
	var commanded_ticks: Array[int] = []

	func apply_fixed_tick(command: FixedTickEventCommand) -> EventDefinition:
		commanded_ticks.append(command.tick)
		return super(command)


static func run(t: TestCase) -> void:
	_required_runtime_files_exist(t)
	if not ResourceLoader.exists("res://src/workplace/workplace_controller.gd"):
		return
	_typed_commands_drive_a_fixed_tick_controller(t)
	_campaign_upgrades_apply_through_commands_and_publish_copies(t)
	_accessibility_defaults_cover_vertical_slice_options(t)
	_main_scene_composes_the_playable_workplace(t)


static func _required_runtime_files_exist(t: TestCase) -> void:
	for path in [
		"res://src/workplace/workplace_controller.gd",
		"res://src/workplace/workplace_commands.gd",
		"res://src/workplace/workplace_view.tscn",
		"res://src/ui/workplace_hud.tscn",
		"res://src/ui/union_hall_view.tscn",
		"res://src/accessibility/accessibility_settings.gd",
		"res://src/campaign/campaign_state.gd",
		"res://src/campaign/apply_upgrade_command.gd",
	]:
		t.check(ResourceLoader.exists(path), "vertical-slice runtime file is loadable: %s" % path)


static func _typed_commands_drive_a_fixed_tick_controller(t: TestCase) -> void:
	var controller_script: GDScript = load("res://src/workplace/workplace_controller.gd")
	var commands: GDScript = load("res://src/workplace/workplace_commands.gd")
	var root := RecordingAppRoot.new()
	root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	root.boot()
	var controller: Variant = controller_script.new()
	controller.configure(root, root.active_catalog, 771)

	controller.advance_frame(0.25)
	var first_view: Dictionary = controller.read_view()
	t.equal(first_view.tick, 1, "one logical quarter-second issues one fixed tick")
	t.equal(root.commanded_ticks, [1], "controller issues a Task 6 command on the first logical tick")
	t.equal(first_view.workers.size(), 12, "controller publishes twelve copied worker views")
	t.equal(first_view.incidents.size(), 1, "fixed-tick event response becomes an inspectable incident")

	controller.apply_command(commands.SelectWorkerCommand.new(&"nib"))
	controller.apply_command(commands.InspectIncidentCommand.new(first_view.incidents[0].id))
	t.equal(controller.read_view().selected_worker_id, &"nib", "typed selection command updates presentation state")
	t.equal(controller.read_view().selected_incident_id, first_view.incidents[0].id, "typed incident command updates presentation state")

	controller.apply_command(commands.PauseCommand.new(true))
	controller.advance_frame(10.0)
	t.equal(controller.read_view().tick, 1, "pause command prevents logical ticks")
	controller.apply_command(commands.PauseCommand.new(false))
	controller.apply_command(commands.SetSpeedCommand.new(4))
	controller.advance_frame(0.25)
	t.equal(controller.read_view().tick, 5, "four-times command advances four fixed ticks per real quarter-second")
	t.equal(root.commanded_ticks, [1, 2, 3, 4, 5], "controller continuously issues one Task 6 command per logical tick")
	var early_result: Dictionary = controller.apply_command(commands.EnterNegotiationCommand.new(&"safety_first"))
	t.check(not early_result.ratified, "workplace cannot ratify before documenting evidence")
	var drag_start := InputEventMouseButton.new()
	drag_start.button_index = MOUSE_BUTTON_LEFT
	drag_start.pressed = true
	drag_start.position = Vector2(700, 400)
	controller._unhandled_input(drag_start)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(1000, 1000)
	controller._unhandled_input(drag_motion)
	var drag_end := InputEventMouseButton.new()
	drag_end.button_index = MOUSE_BUTTON_LEFT
	drag_end.pressed = false
	drag_end.position = Vector2(700, 400)
	controller._unhandled_input(drag_end)
	var input_view: Dictionary = controller.read_view()
	t.check(input_view.has("pan_offset"), "workplace publishes its bounded pan view")
	if not input_view.has("pan_offset"):
		controller.free()
		root.free()
		return
	t.equal(input_view.pan_offset, Vector2(190, 115), "primary drag pans the mine within laptop-safe bounds")
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 10.0
	controller._unhandled_input(magnify)
	t.equal(controller.read_view().zoom, 1.28, "trackpad magnification respects the maximum zoom bound")

	var resources_before_document: Dictionary = controller.read_view().resources
	var document_result: Dictionary = controller.apply_command(commands.ProposeActionCommand.new(&"document", first_view.incidents[0].id))
	t.check(document_result.executed, "testimony documents through a typed proposal command")
	t.equal(controller.read_view().resources, resources_before_document, "documentation does not manufacture organizing resources")
	var documented_view: Dictionary = controller.read_view()
	t.check(documented_view.has("action_forecasts"), "workplace publishes action forecasts")
	if not documented_view.has("action_forecasts"):
		controller.free()
		root.free()
		return
	t.check(documented_view.action_forecasts.informal.can_execute, "documented case publishes the first executable informal forecast")
	var prepared_result: Dictionary = controller.apply_command(commands.EnterNegotiationCommand.new(&"safety_first"))
	t.check(prepared_result.ratified, "documented evidence changes the package into a ratifiable agreement")
	t.check(int(prepared_result.package.safety.concession_rank) > int(early_result.package.safety.concession_rank), "documented evidence improves the safety clause")
	for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
		var action_result: Dictionary = controller.apply_command(commands.ProposeActionCommand.new(action, first_view.incidents[0].id))
		t.check(action_result.executed, "%s executes through the sequential organizing command API" % action)
	var resources_after_action: Dictionary = controller.read_view().resources
	for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
		var settled_forecast: Dictionary = controller.read_view().action_forecasts[action]
		t.check(not settled_forecast.can_execute, "completed ladder blocks the %s forecast" % action)
		t.check(String(settled_forecast.blocker).contains("remedy"), "completed ladder forecast explains the remedy transition")
	var repeated_action: Dictionary = controller.apply_command(commands.ProposeActionCommand.new(&"work_to_rule", first_view.incidents[0].id))
	t.check(not repeated_action.executed, "the same work-to-rule action cannot execute twice")
	t.equal(controller.read_view().resources, resources_after_action, "repeated grievance action cannot mint solidarity")
	var remedy_result: Dictionary = controller.apply_command(commands.ApplyRemedyCommand.new(first_view.incidents[0].id, &"shoring_repair"))
	t.check(remedy_result.applied, "a separate typed remedy settles the fully escalated case")
	controller.apply_command(commands.SetSpeedCommand.new(4))
	controller.advance_frame(45.0)
	var second_view: Dictionary = controller.read_view()
	t.equal(second_view.active_incidents.size(), 1, "resolving an incident allows a later authored incident to become active")
	t.equal(second_view.incident_history.size(), 1, "resolved occurrence remains available as read-only history")
	t.check(second_view.paused, "a later major event auto-pauses accelerated simulation")
	t.check(second_view.tick < 725, "auto-pause stops remaining logical ticks in a large render frame")
	t.check(int(second_view.get("deferred_ticks", 0)) > 0, "auto-pause preserves every unprocessed logical tick")
	controller.accessibility_settings.auto_pause_major_events = false
	controller.apply_command(commands.SetSpeedCommand.new(1))
	controller.advance_frame(0.0)
	t.equal(controller.read_view().tick, 725, "resuming consumes every preserved tick from the large render frame")
	for index in root.commanded_ticks.size():
		t.equal(root.commanded_ticks[index], index + 1, "fixed-tick commands remain gap-free after auto-pause")

	var workers_copy: Array = controller.read_view().workers
	workers_copy.clear()
	t.equal(controller.read_view().workers.size(), 12, "published workplace views cannot mutate controller state")
	controller.free()
	root.free()


static func _campaign_upgrades_apply_through_commands_and_publish_copies(t: TestCase) -> void:
	var campaign_script: GDScript = load("res://src/campaign/campaign_state.gd")
	var command_script: GDScript = load("res://src/campaign/apply_upgrade_command.gd")
	var campaign: Variant = campaign_script.new(5)
	var branches: Array[StringName] = [
		&"steward_school", &"legal_desk", &"mutual_aid_kitchen", &"print_shop", &"organizing_workshop",
	]
	for branch in branches:
		t.check(campaign.apply_command(command_script.new(branch, 1)), "campaign accepts the first upgrade in %s" % branch)
	var view: Dictionary = campaign.read_view()
	t.equal(view.upgrades.size(), 5, "union hall exposes one purchased upgrade in every branch")
	t.equal(view.upgrade_points, 0, "campaign command spends one point per branch")
	view.upgrades.clear()
	t.equal(campaign.read_view().upgrades.size(), 5, "campaign read view is isolated from presentation mutation")
	t.check(not campaign.apply_command(command_script.new(&"legal_desk", 2)), "slice rejects unavailable second-tier upgrades")


static func _accessibility_defaults_cover_vertical_slice_options(t: TestCase) -> void:
	var settings: Resource = load("res://src/accessibility/accessibility_settings.gd").new()
	t.equal(settings.ui_scale, 1.0, "interface scale defaults to one")
	t.check(settings.auto_pause_major_events, "major incidents auto-pause by default")
	t.check(not settings.reduced_motion, "reduced motion is opt-in")
	t.check(not settings.high_contrast, "high contrast is opt-in")
	t.check(not settings.dyslexia_friendly_font, "dyslexia-friendly font is opt-in")
	var hud: Control = load("res://src/ui/workplace_hud.tscn").instantiate()
	hud._ready()
	settings.ui_scale = 2.0
	settings.dyslexia_friendly_font = true
	hud.set_accessibility(settings)
	t.equal(hud.scale, Vector2.ONE, "maximum UI scale reflows text without clipping the fixed logical canvas")
	for child in hud.get_children():
		if child is Button:
			t.check(child.position.x + child.size.x <= 1440.0, "scaled HUD button remains inside the logical viewport")
	hud.free()
	var hall: Control = load("res://src/ui/union_hall_view.tscn").instantiate()
	hall._ready()
	t.check(hall.has_method("set_accessibility"), "union hall exposes the shared accessibility application")
	if hall.has_method("set_accessibility"):
		hall.set_accessibility(settings)
	t.equal(hall.scale, Vector2.ONE, "union hall applies accessible text without clipping its layout")
	hall.free()


static func _main_scene_composes_the_playable_workplace(t: TestCase) -> void:
	var packed: PackedScene = load("res://src/app/app_root.tscn")
	var root: Node = packed.instantiate()
	t.check(root.has_node("WorkplaceView"), "boot scene includes the playable workplace")
	var workplace: Node = root.get_node("WorkplaceView")
	t.check(workplace.has_node("MineViewport"), "workplace keeps a dedicated fixed-orientation mine layer")
	t.check(workplace.has_node("WorkplaceHUD"), "workplace includes the stable three-region HUD")
	root.free()
