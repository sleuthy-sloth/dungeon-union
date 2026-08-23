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
	var long_view: Dictionary = workplace.read_view()
	long_view["selected_incident_id"] = StringName(active_incidents[0].id)
	long_view.active_incidents[0]["title"] = "Ventilation refusal, shoring inspection, and uncompensated emergency repair"
	long_view.active_incidents[0]["description"] = ("Brakka reports repeated roof movement above the west face after the foreman removed two braces. The lantern crew also records dense blue fumes through the full haul corridor, while the repair ledger shows an uncompensated emergency shift. Workers need the complete narrative visible without covering evidence, forecasts, action controls, or the union-hall route.\n\n").repeat(5)
	long_view["incidents"] = long_view.active_incidents
	long_view.workers[0]["display_name"] = "Nib Copperthumb, West-Face Safety Delegate"
	app.free()

	# This fixture is deliberately detached from WorkplaceController so awaited layout
	# frames cannot replace its long authored content with a live presentation refresh.
	var settled_hud: WorkplaceHUD = load("res://src/ui/workplace_hud.tscn").instantiate()
	settled_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settled_hud.size = Vector2(1440, 900)
	tree.root.add_child(settled_hud)
	settled_hud.update_view(long_view)
	var settled_hall: UnionHallView = load("res://src/ui/union_hall_view.tscn").instantiate()
	settled_hall.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settled_hall.size = Vector2(1440, 900)
	tree.root.add_child(settled_hall)
	var previous_font_size := 0
	var previous_narrative_height := 0.0
	var previous_right_extent := Vector2.ZERO
	for supported_scale in [0.75, 1.0, 1.5, 2.0]:
		var settings := AccessibilitySettings.new()
		settings.ui_scale = supported_scale
		settings.high_contrast = true
		settings.reduced_motion = true
		settings.dyslexia_friendly_font = true
		settled_hud.set_accessibility(settings)
		settled_hall.set_accessibility(settings)
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
		var layout: Dictionary = settled_hud.accessibility_layout_view()
		t.check(layout.get("all_inside_viewport", false), "%.2f UI layout keeps visible scroll regions inside the viewport" % supported_scale)
		t.check(layout.get("no_intersections", false), "%.2f UI layout keeps stable regions from intersecting" % supported_scale)
		t.check(layout.get("focus_outlines", false), "%.2f UI layout retains visible focus outlines" % supported_scale)
		var narrative: Control = settled_hud.find_child("CaseNarrative", true, false)
		var narrative_font_size := narrative.get_theme_font_size("font_size") if narrative != null else 0
		var right_extent: Vector2 = layout.get("right_content_extent", Vector2.ZERO)
		t.check(narrative_font_size > 0, "%.2f settled narrative publishes a real font metric" % supported_scale)
		t.check(right_extent.y > float(layout.get("right_region_rect", Rect2()).size.y), "%.2f long case file creates usable vertical scroll extent" % supported_scale)
		if previous_font_size > 0:
			t.check(narrative_font_size > previous_font_size, "%.2f increases actual typography instead of a reset child transform" % supported_scale)
			t.check(narrative.size.y > previous_narrative_height, "%.2f increases settled narrative geometry" % supported_scale)
			t.check(right_extent.y > previous_right_extent.y, "%.2f increases the content scroll extent" % supported_scale)
		previous_font_size = narrative_font_size
		previous_narrative_height = narrative.size.y
		previous_right_extent = right_extent
		var control_rects: Array = layout.get("control_rects", [])
		t.check(not control_rects.is_empty(), "%.2f publishes every full control rectangle, including clipped leaves" % supported_scale)
		for left_index in control_rects.size():
			for right_index in range(left_index + 1, control_rects.size()):
				if control_rects[left_index].region == control_rects[right_index].region:
					t.check(not control_rects[left_index].rect.intersects(control_rects[right_index].rect), "%.2f full settled controls do not intersect: %s / %s" % [supported_scale, control_rects[left_index].name, control_rects[right_index].name])
		var visible_rects: Array = layout.get("visible_rects", [])
		t.check(not visible_rects.is_empty(), "%.2f settled layout publishes full and clipped visible rectangles" % supported_scale)
		for item in visible_rects:
			var visible_rect: Rect2 = item.get("visible_rect", Rect2())
			t.check(visible_rect.has_area() and Rect2(Vector2.ZERO, Vector2(1440, 900)).encloses(visible_rect), "%.2f clipped %s bounds stay within the viewport" % [supported_scale, item.name])
		await _assert_horizontal_scroll_reaches_full_content(t, tree, settled_hud, supported_scale)
		var hall_button: Button = settled_hud.find_child("UnionHallAction", true, false)
		var right_scroll := _ancestor_scroll(hall_button)
		t.check(hall_button != null and right_scroll != null, "%.2f union-hall route belongs to the contextual scroll region" % supported_scale)
		if hall_button != null and right_scroll != null:
			right_scroll.scroll_vertical = 0
			var first_worker: Button = settled_hud.worker_button(&"nib")
			first_worker.grab_focus()
			hall_button.grab_focus()
			await tree.process_frame
			await tree.process_frame
			var hall_rect := _global_rect(hall_button)
			t.check(hall_rect.intersects(right_scroll.get_global_rect()), "%.2f focusing the off-clip Union Hall route scrolls it visibly into view" % supported_scale)
			t.equal(tree.root.gui_get_focus_owner(), hall_button, "%.2f scrolled Union Hall route retains keyboard focus" % supported_scale)
			t.check(hall_button.has_theme_stylebox_override("focus"), "%.2f focused Union Hall route has a visible focus border" % supported_scale)
		var hall_layout: Dictionary = settled_hall.accessibility_layout_view()
		t.check(hall_layout.get("all_inside_viewport", false) and hall_layout.get("scrollable_reflow", false), "%.2f union hall uses bounded scrollable reflow: %s" % [supported_scale, hall_layout])
		t.check(hall_layout.get("high_contrast", false) and hall_layout.get("reduced_motion", false) and hall_layout.get("dyslexia_friendly_font", false), "%.2f union hall receives every visual accessibility setting" % supported_scale)
		t.equal(hall_layout.get("body_font_size", 0), maxi(1, int(round(12.0 * supported_scale))), "%.2f union hall scales actual typography" % supported_scale)
	settled_hud.free()
	settled_hall.free()


static func _ancestor_scroll(control: Control) -> ScrollContainer:
	var current: Node = control
	while current != null:
		if current is ScrollContainer:
			return current
		current = current.get_parent()
	return null


static func _global_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var minimum := transform * Vector2.ZERO
	var maximum := minimum
	for point in [
		transform * Vector2(control.size.x, 0),
		transform * control.size,
		transform * Vector2(0, control.size.y),
	]:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func _assert_horizontal_scroll_reaches_full_content(
	t: TestCase,
	tree: SceneTree,
	hud: WorkplaceHUD,
	supported_scale: float
) -> void:
	var representative_groups := [
		[
			hud.find_child("WorkerColumns", true, false),
			hud.find_child("WorkerRow00", true, false),
		],
		[
			hud.find_child("CaseHeading", true, false),
			hud.find_child("CaseTitle", true, false),
		],
	]
	for representatives in representative_groups:
		var focus_control: Control = representatives[1]
		var scroll := _ancestor_scroll(focus_control)
		var content := _scroll_content(scroll)
		t.check(scroll != null and content != null, "%.2f representative controls own real scroll content" % supported_scale)
		if scroll == null or content == null:
			continue
		var content_extent := Rect2(Vector2.ZERO, content.size.max(content.custom_minimum_size))
		for leaf in content.find_children("*", "Control", true, false):
			if (leaf is Label or leaf is Button) and leaf.is_visible_in_tree():
				var leaf_rect := _rect_relative_to(leaf, content)
				t.check(content_extent.grow(0.5).encloses(leaf_rect), "%.2f full %s leaf lies inside its horizontal scroll content extent" % [supported_scale, leaf.name])
		if focus_control is Button:
			focus_control.grab_focus()
		await tree.process_frame
		scroll.scroll_horizontal = 0
		await tree.process_frame
		await tree.process_frame
		var viewport_rect := _scroll_viewport_rect(scroll)
		for control in representatives:
			var left_rect := _global_rect(control).grow(3.0)
			t.check(left_rect.position.x >= viewport_rect.position.x - 0.5 and left_rect.position.x <= viewport_rect.end.x, "%.2f minimum scroll reveals full left edge for %s" % [supported_scale, control.name])
		scroll.scroll_horizontal = 1000000
		await tree.process_frame
		await tree.process_frame
		viewport_rect = _scroll_viewport_rect(scroll)
		for control in representatives:
			var right_rect := _global_rect(control).grow(3.0)
			t.check(right_rect.end.x <= viewport_rect.end.x + 0.5 and right_rect.end.x >= viewport_rect.position.x, "%.2f maximum scroll reveals full right edge for %s" % [supported_scale, control.name])
		if focus_control is Button:
			t.check(focus_control.has_theme_stylebox_override("focus"), "%.2f representative roster focus border remains authored" % supported_scale)


static func _scroll_content(scroll: ScrollContainer) -> Control:
	if scroll == null:
		return null
	for child in scroll.get_children():
		if child is Control and child != scroll.get_h_scroll_bar() and child != scroll.get_v_scroll_bar():
			return child
	return null


static func _rect_relative_to(control: Control, ancestor: Control) -> Rect2:
	var inverse := ancestor.get_global_transform_with_canvas().affine_inverse()
	var transform := control.get_global_transform_with_canvas()
	var minimum := inverse * (transform * Vector2.ZERO)
	var maximum := minimum
	for point in [
		inverse * (transform * Vector2(control.size.x, 0)),
		inverse * (transform * control.size),
		inverse * (transform * Vector2(0, control.size.y)),
	]:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func _scroll_viewport_rect(scroll: ScrollContainer) -> Rect2:
	var result := scroll.get_global_rect()
	var vertical_bar := scroll.get_v_scroll_bar()
	if vertical_bar.visible:
		result.size.x -= vertical_bar.size.x
	var horizontal_bar := scroll.get_h_scroll_bar()
	if horizontal_bar.visible:
		result.size.y -= horizontal_bar.size.y
	return result
