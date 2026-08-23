extends RefCounted


static func run(t: TestCase) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var app: AppRoot = load("res://src/app/app_root.tscn").instantiate()
	tree.root.add_child(app)
	app.begin_shift(false)
	var workplace: WorkplaceController = app.get_node("WorkplaceView")
	var hud: WorkplaceHUD = workplace.get_node("WorkplaceHUD")
	var hall: UnionHallView = workplace.get_node("UnionHallView")
	var required_actions: Dictionary[StringName, Key] = {
		&"workplace_focus_next": KEY_DOWN,
		&"workplace_focus_previous": KEY_UP,
		&"workplace_focus_right": KEY_RIGHT,
		&"workplace_focus_left": KEY_LEFT,
		&"workplace_activate": KEY_ENTER,
		&"workplace_union_hall": KEY_U,
		&"workplace_back": KEY_B,
		&"workplace_cycle_incident": KEY_TAB,
	}
	var bindings_ready := true
	for action in required_actions:
		var has_binding := InputMap.has_action(action) and _has_key_binding(action, required_actions[action])
		t.check(has_binding, "%s is an explicit remappable single-key InputMap action" % action)
		bindings_ready = bindings_ready and has_binding
	var focus_api_ready := hud.has_method("focus_initial") and hud.has_method("focus_move") and hall.has_method("focus_initial") and hall.has_method("focus_move") and hall.has_method("close_view")
	t.check(focus_api_ready, "HUD and union hall expose an explicit focus-neighbor navigation boundary")
	if not bindings_ready or not focus_api_ready:
		app.free()
		return

	workplace.accessibility_settings.auto_pause_major_events = false
	workplace.advance_frame(0.25)
	workplace.advance_frame(75.0)
	await tree.process_frame
	var first_worker: Button = tree.root.gui_get_focus_owner() as Button
	var first_worker_id := StringName(first_worker.get_meta("worker_id", &"")) if first_worker != null else &""
	t.check(first_worker != null and not first_worker_id.is_empty() and hud.worker_button(first_worker_id) == first_worker, "playable scene gives initial focus to the first visible worker")
	t.check(first_worker != null and first_worker.has_theme_stylebox_override("focus"), "initial worker focus has a visible authored outline")
	t.check(first_worker != null and not first_worker.focus_neighbor_bottom.is_empty(), "worker focus owns an explicit neighbor into the HUD path")
	await _press_key(tree, KEY_ENTER)
	t.equal(workplace.read_view().selected_worker_id, first_worker_id, "Enter activates the initially focused worker")

	var grievance_occurrence: Dictionary = {}
	for occurrence in workplace.read_view().active_incidents:
		if StringName(occurrence.event_kind) == EventDefinition.GRIEVANCE_KIND:
			grievance_occurrence = occurrence
			break
	t.check(not grievance_occurrence.is_empty(), "keyboard fixture has a grievance occurrence")
	if grievance_occurrence.is_empty():
		app.free()
		return
	var incident_button: Button = hud.incident_button(StringName(grievance_occurrence.id))
	t.check(await _focus_until(tree, incident_button, KEY_DOWN, 24), "Down reaches the incident list across the roster scroll region")
	t.check(incident_button != null and not incident_button.focus_neighbor_bottom.is_empty(), "incident focus owns an explicit neighbor into the case-file path")
	await _press_key(tree, KEY_ENTER)
	t.equal(workplace.read_view().selected_incident_id, grievance_occurrence.id, "Enter inspects the focused incident")

	var document_button: Button = hud.find_child("DocumentAction", true, false)
	t.check(await _focus_until(tree, document_button, KEY_DOWN, 12), "Down crosses into the case-file action region")
	await _press_key(tree, KEY_ENTER)
	var documented := _grievance_view(workplace.durable_snapshot().grievances, StringName(grievance_occurrence.id))
	t.equal(documented.get("phase", &""), &"documented", "Enter activates documentation from keyboard focus")
	var informal_button: Button = hud.find_child("OrganizingAction00", true, false)
	t.check(await _focus_until(tree, informal_button, KEY_DOWN, 4), "Down reaches the first organizing action")
	await _press_key(tree, KEY_ENTER)
	var escalated := _grievance_view(workplace.durable_snapshot().grievances, StringName(grievance_occurrence.id))
	t.equal(escalated.get("action_history", []), [&"informal"], "Enter commits the focused organizing action")

	await _press_key(tree, KEY_U)
	t.check(hall.visible, "single-key hall action opens the Union Hall")
	var upgrade_focus: Control = tree.root.gui_get_focus_owner()
	t.check(upgrade_focus is Button and upgrade_focus.has_meta("upgrade_branch"), "Union Hall opens with an upgrade control focused")
	t.check(upgrade_focus != null and not upgrade_focus.focus_neighbor_right.is_empty(), "focused upgrade owns an explicit hall navigation neighbor")
	await _press_key(tree, KEY_ENTER)
	t.equal(workplace.durable_snapshot().campaign.upgrades.size(), 1, "Enter installs the focused hall upgrade")
	await _press_key(tree, KEY_B)
	t.check(not hall.visible, "single-key Back closes the Union Hall")
	t.equal(tree.root.gui_get_focus_owner(), hud.union_hall_button(), "Back restores visible focus to the mine-side hall route")

	var selected_before_tab := StringName(workplace.read_view().selected_incident_id)
	await _press_key(tree, KEY_TAB)
	t.check(StringName(workplace.read_view().selected_incident_id) != selected_before_tab, "unmodified Tab still cycles incidents instead of moving focus")
	app.free()


static func _focus_until(tree: SceneTree, target: Control, keycode: Key, maximum_steps: int) -> bool:
	if target == null:
		return false
	for step in maximum_steps + 1:
		if tree.root.gui_get_focus_owner() == target:
			return true
		await _press_key(tree, keycode)
	return false


static func _press_key(tree: SceneTree, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	tree.root.push_input(event)
	await tree.process_frame


static func _has_key_binding(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false


static func _grievance_view(grievances: Array, grievance_id: StringName) -> Dictionary:
	for grievance in grievances:
		if StringName(grievance.id) == grievance_id:
			return grievance.duplicate(true)
	return {}
