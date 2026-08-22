extends RefCounted


static func run(t: TestCase) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	t.check(tree != null, "acceptance tests run inside an initialized scene tree")
	if tree == null:
		return
	var app: Node = load("res://src/app/app_root.tscn").instantiate()
	tree.root.add_child(app)
	var workplace: WorkplaceController = app.get_node("WorkplaceView")
	t.check(workplace.has_node("MineInputSurface"), "workplace owns a dedicated central GUI input surface")
	if not workplace.has_node("MineInputSurface"):
		app.free()
		return
	var surface: Control = workplace.get_node("MineInputSurface")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(500, 300)
	surface.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 40)
	surface.gui_input.emit(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	surface.gui_input.emit(release)
	t.equal(workplace.read_view().pan_offset, Vector2(80, 40), "scene-dispatched primary drag pans through the GUI surface")
	workplace.accessibility_settings.auto_pause_major_events = false
	workplace.advance_frame(0.25)
	workplace.advance_frame(75.0)
	var hud: WorkplaceHUD = workplace.get_node("WorkplaceHUD")
	t.check(hud.has_method("worker_button") and hud.has_method("incident_button"), "HUD exposes focusable worker and incident controls")
	var active_incidents: Array = workplace.read_view().active_incidents
	t.check(active_incidents.size() >= 2, "viewport shortcut fixture has at least two simultaneously active authored occurrences")
	if not active_incidents.is_empty():
		var case_button: Button = hud.incident_button(StringName(active_incidents[0].id))
		t.check(case_button != null and case_button.focus_mode == Control.FOCUS_ALL, "active incident has a clickable, keyboard-focusable case control")
		if case_button != null:
			case_button.pressed.emit()
			t.equal(workplace.read_view().selected_incident_id, active_incidents[0].id, "incident control dispatches typed contextual inspection")
	if hud.has_method("worker_button"):
		var worker_button: Button = hud.worker_button(&"nib")
		worker_button.pressed.emit()
		t.equal(workplace.read_view().selected_worker_id, &"nib", "clickable worker selection updates context")
		t.check(String(hud.context_text()).contains("Nib"), "right panel publishes contextual worker details")
	if active_incidents.size() < 2:
		app.free()
		return
	workplace.apply_command(WorkplaceCommands.InspectIncidentCommand.new(StringName(active_incidents[0].id)))
	var worker_button: Button = hud.worker_button(&"nib")
	worker_button.grab_focus()
	await tree.process_frame
	var expected_next_id := StringName(active_incidents[1].id)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	tree.root.push_input(tab)
	await tree.process_frame
	t.equal(workplace.read_view().selected_incident_id, expected_next_id, "unmodified Tab cycles to the exact next occurrence while a button owns focus")
	var incident_after_cycle: StringName = workplace.read_view().selected_incident_id
	var focus_before_navigation: Control = tree.root.gui_get_focus_owner()
	var focus_previous := InputEventKey.new()
	focus_previous.keycode = KEY_TAB
	focus_previous.shift_pressed = true
	focus_previous.pressed = true
	tree.root.push_input(focus_previous)
	await tree.process_frame
	t.equal(workplace.read_view().selected_incident_id, incident_after_cycle, "modified Tab is reserved for GUI focus navigation and does not cycle incidents")
	t.check(tree.root.gui_get_focus_owner() != focus_before_navigation, "modified Tab preserves keyboard focus traversal")
	var hall: UnionHallView = workplace.get_node("UnionHallView")
	var long_view: Dictionary = workplace.read_view()
	long_view["selected_incident_id"] = StringName(active_incidents[0].id)
	long_view.active_incidents[0]["title"] = "Ventilation refusal, shoring inspection, and uncompensated emergency repair"
	long_view.active_incidents[0]["description"] = "Brakka reports repeated roof movement above the west face after the foreman removed two braces. The lantern crew also records dense blue fumes through the full haul corridor, while the repair ledger shows an uncompensated emergency shift. Workers need the complete narrative visible without covering evidence, forecasts, action controls, or the union-hall route."
	long_view["incidents"] = long_view.active_incidents
	long_view.workers[0]["display_name"] = "Nib Copperthumb, West-Face Safety Delegate"
	hud.update_view(long_view)
	for supported_scale in [0.75, 1.0, 1.5, 2.0]:
		var settings := AccessibilitySettings.new()
		settings.ui_scale = supported_scale
		settings.high_contrast = true
		settings.reduced_motion = true
		settings.dyslexia_friendly_font = true
		hud.set_accessibility(settings)
		hall.set_accessibility(settings)
		await tree.process_frame
		await tree.process_frame
		var layout: Dictionary = hud.accessibility_layout_view()
		t.check(layout.get("all_inside_viewport", false), "%.2f UI layout keeps visible scroll regions inside the viewport" % supported_scale)
		t.check(layout.get("no_intersections", false), "%.2f UI layout keeps stable regions from intersecting" % supported_scale)
		t.check(layout.get("focus_outlines", false), "%.2f UI layout retains visible focus outlines" % supported_scale)
		var visible_rects: Array = layout.get("visible_rects", [])
		t.check(not visible_rects.is_empty(), "%.2f settled layout publishes transformed visible rectangles" % supported_scale)
		for item in visible_rects:
			t.check(Rect2(Vector2.ZERO, Vector2(1440, 900)).encloses(item.rect), "%.2f transformed %s bounds stay within the viewport" % [supported_scale, item.name])
		for left_index in visible_rects.size():
			for right_index in range(left_index + 1, visible_rects.size()):
				if visible_rects[left_index].region == visible_rects[right_index].region:
					t.check(not visible_rects[left_index].rect.intersects(visible_rects[right_index].rect), "%.2f settled controls do not intersect: %s / %s" % [supported_scale, visible_rects[left_index].name, visible_rects[right_index].name])
		var hall_layout: Dictionary = hall.accessibility_layout_view()
		t.check(hall_layout.get("all_inside_viewport", false) and hall_layout.get("scrollable_reflow", false), "%.2f union hall uses bounded scrollable reflow" % supported_scale)
		t.check(hall_layout.get("high_contrast", false) and hall_layout.get("reduced_motion", false) and hall_layout.get("dyslexia_friendly_font", false), "%.2f union hall receives every visual accessibility setting" % supported_scale)
	app.free()
