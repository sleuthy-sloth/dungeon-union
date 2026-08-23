class_name WorkplaceHUD
extends Control

signal command_requested(command: Variant)
signal union_hall_requested

const WorkplaceCommandsScript = preload("res://src/workplace/workplace_commands.gd")

const COAL := Color("0b1114")
const SLATE := Color("16242b")
const PAPER := Color("e8d9b5")
const BRASS := Color("d2a75c")
const UNION_RED := Color("a54138")
const SAFETY_TEAL := Color("79b7b0")

var _display_font: SystemFont
var _body_font: SystemFont
var _data_font: SystemFont
var _accessible_font: SystemFont
var _worker_buttons: Array[Button] = []
var _incident_buttons: Array[Button] = []
var _labels: Dictionary[StringName, Label] = {}
var _view: Dictionary = {}
var _settings := AccessibilitySettings.new()
var _scroll_regions: Array[ScrollContainer] = []
var _scaled_contents: Array[Control] = []
var _left_stack: VBoxContainer
var _right_stack: VBoxContainer
var _action_grid: GridContainer
var _document_button: Button
var _action_buttons: Array[Button] = []
var _remedy_button: Button
var _negotiate_button: Button
var _hall_button: Button
var _save_button: Button
var _load_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_fonts()
	_build_interface()
	_build_scroll_regions()
	_build_panel_stacks()
	call_deferred(&"_settle_panel_layout")
	queue_redraw()


func update_view(view: Dictionary) -> void:
	_view = view.duplicate(true)
	if not is_node_ready():
		return
	_labels.time.text = "DAY %02d  ·  %s  ·  TICK %04d" % [int(view.get("workday", 1)), "PAUSED" if view.get("paused", false) else "%dx" % int(view.get("speed", 1)), int(view.get("tick", 0))]
	var resources: Dictionary = view.get("resources", {})
	_labels.resources.text = "TREASURY  %02d     SOLIDARITY  %02d%%     PRESSURE  %02d%%" % [int(resources.get("treasury", 0)), int(resources.get("solidarity", 0)), int(view.get("employer_pressure", 0))]
	var workers: Array = view.get("workers", [])
	for index in _worker_buttons.size():
		var button := _worker_buttons[index]
		button.visible = index < workers.size()
		if index >= workers.size():
			continue
		var worker: Dictionary = workers[index]
		button.set_meta("worker_id", StringName(worker.id))
		button.text = "%s  %-19s %3d" % [_species_symbol(StringName(worker.get("species", &""))), String(worker.get("display_name", worker.id)), int(worker.get("fatigue", 0))]
		button.button_pressed = StringName(worker.id) == StringName(view.get("selected_worker_id", &""))
	var incidents: Array = view.get("active_incidents", view.get("incidents", []))
	_labels.grievances_list.visible = incidents.is_empty()
	for index in _incident_buttons.size():
		var incident_button := _incident_buttons[index]
		incident_button.visible = index < incidents.size()
		if index < incidents.size():
			var incident: Dictionary = incidents[index]
			incident_button.set_meta("incident_id", StringName(incident.id))
			if StringName(incident.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
				incident_button.text = "✦ %-15s %s" % [String(incident.get("title", incident.id)).left(15), String(incident.get("completion", "active")).to_upper()]
			else:
				incident_button.text = "⚠ %-15s %s" % [String(incident.get("title", incident.id)).left(15), String(incident.get("grievance_phase", "reported")).to_upper()]
			incident_button.button_pressed = StringName(incident.id) == StringName(view.get("selected_incident_id", &""))
	_update_case_file(view)
	_refresh_focus_neighbors()
	call_deferred(&"_settle_panel_layout")
	queue_redraw()


func set_accessibility(settings: AccessibilitySettings) -> void:
	_settings = settings.normalized_copy()
	scale = Vector2.ONE
	for content in _scaled_contents:
		content.scale = Vector2.ONE
		content.custom_minimum_size = Vector2(content.get_meta("base_size")) * _settings.ui_scale
	for child in find_children("*", "Control", true, false):
		if child.has_meta("base_font_size"):
			child.add_theme_font_size_override("font_size", maxi(1, int(round(float(child.get_meta("base_font_size")) * _settings.ui_scale))))
			var base_font: Font = child.get_meta("base_font")
			child.add_theme_font_override("font", _accessible_font if _settings.dyslexia_friendly_font else base_font)
		if child.has_meta("flow_minimum_size"):
			child.custom_minimum_size = Vector2(child.get_meta("flow_minimum_size")) * _settings.ui_scale
		elif child.has_meta("base_position") and child.has_meta("base_size"):
			child.position = Vector2(child.get_meta("base_position")) * _settings.ui_scale
			child.size = Vector2(child.get_meta("base_size")) * _settings.ui_scale
	_scale_container(_left_stack, Vector2(16, 14), 278.0, 4)
	_scale_container(_right_stack, Vector2(20, 16), 258.0, 7)
	if _action_grid != null:
		_action_grid.custom_minimum_size = Vector2(258, 73) * _settings.ui_scale
		_action_grid.add_theme_constant_override("h_separation", maxi(1, int(round(6.0 * _settings.ui_scale))))
		_action_grid.add_theme_constant_override("v_separation", maxi(1, int(round(5.0 * _settings.ui_scale))))
	call_deferred(&"_settle_panel_layout")
	queue_redraw()


func worker_button(worker_id: StringName) -> Button:
	for button in _worker_buttons:
		if StringName(button.get_meta("worker_id", &"")) == worker_id:
			return button
	return null


func incident_button(incident_id: StringName) -> Button:
	for button in _incident_buttons:
		if StringName(button.get_meta("incident_id", &"")) == incident_id:
			return button
	return null


func context_text() -> String:
	return "%s\n%s" % [_labels.case_title.text, _labels.case_body.text]


func union_hall_button() -> Button:
	return _hall_button


func focus_initial() -> void:
	var sequence := _focus_sequence()
	if not sequence.is_empty():
		sequence[0].grab_focus()


func focus_move(direction: int) -> void:
	var sequence := _focus_sequence()
	if sequence.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var index := sequence.find(owner)
	if index < 0:
		index = 0 if direction >= 0 else sequence.size() - 1
	else:
		index = posmod(index + (1 if direction >= 0 else -1), sequence.size())
	sequence[index].grab_focus()


func accessibility_layout_view() -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1440, 900))
	var inside := true
	for region in _scroll_regions:
		inside = inside and viewport_rect.encloses(region.get_global_rect())
	var control_rects := _layout_control_rects()
	var visible_rects: Array[Dictionary] = []
	for item in control_rects:
		if item.visible_rect.has_area():
			visible_rects.append(item)
	var non_intersecting := true
	for left_index in control_rects.size():
		for right_index in range(left_index + 1, control_rects.size()):
			if control_rects[left_index].region == control_rects[right_index].region:
				non_intersecting = non_intersecting and not control_rects[left_index].rect.intersects(control_rects[right_index].rect)
	for item in visible_rects:
		inside = inside and viewport_rect.encloses(item.visible_rect)
	var outlined := true
	for button in find_children("*", "Button", true, false):
		outlined = outlined and button.focus_mode == Control.FOCUS_ALL and button.has_theme_stylebox_override("focus")
	return {
		"all_inside_viewport": inside,
		"no_intersections": non_intersecting,
		"focus_outlines": outlined,
		"visible_rects": visible_rects,
		"control_rects": control_rects,
		"right_region_rect": _scroll_regions[2].get_global_rect(),
		"right_content_extent": _scaled_contents[2].size.max(_scaled_contents[2].custom_minimum_size),
	}


func _draw() -> void:
	# Stable top rail.
	draw_rect(Rect2(0, 0, 1440, 66), COAL)
	draw_line(Vector2(0, 65), Vector2(1440, 65), PAPER if _settings.high_contrast else BRASS, 2.0)
	# Clipped paper docket, intentionally square and not card-like.
	var left := PackedVector2Array([Vector2(18, 84), Vector2(328, 84), Vector2(328, 842), Vector2(42, 842), Vector2(18, 816)])
	draw_colored_polygon(left, PAPER)
	draw_polyline(_closed(left), COAL, 3.0, true)
	draw_line(Vector2(34, 152), Vector2(310, 152), UNION_RED, 4.0)
	for y in range(169, 815, 39):
		draw_line(Vector2(35, y), Vector2(310, y), Color(COAL, 0.16), 1.0)
	# Cut-corner case file.
	var right := PackedVector2Array([Vector2(1112, 84), Vector2(1418, 84), Vector2(1418, 816), Vector2(1392, 842), Vector2(1112, 842)])
	draw_colored_polygon(right, SLATE)
	draw_polyline(_closed(right), PAPER if _settings.high_contrast else BRASS, 2.0, true)
	# The organizing thread connects roster, incident marker, and grievance docket.
	var thread := PackedVector2Array([Vector2(312, 206), Vector2(365, 206), Vector2(391, 244), Vector2(1044, 244), Vector2(1070, 206), Vector2(1112, 206)])
	draw_polyline(thread, PAPER if _settings.high_contrast else UNION_RED, 5.0, true)
	for point in [thread[0], thread[3], thread[5]]:
		draw_circle(point, 7.0, UNION_RED)
		draw_arc(point, 10.0, 0, TAU, 20, PAPER, 2.0)
	# Color-independent hazard hatch on case file margin.
	for y in range(300, 510, 18):
		draw_line(Vector2(1384, y), Vector2(1404, y + 12), SAFETY_TEAL, 3.0)


func _build_fonts() -> void:
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Palatino", "Book Antiqua", "Times New Roman"])
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue", "Arial"])
	_data_font = SystemFont.new()
	_data_font.font_names = PackedStringArray(["Menlo", "Monaco", "Courier New"])
	_accessible_font = SystemFont.new()
	_accessible_font.font_names = PackedStringArray(["Atkinson Hyperlegible", "Arial", "Helvetica"])


func _build_interface() -> void:
	_labels.time = _label("DAY 01  ·  PAUSED  ·  TICK 0000", Vector2(24, 17), Vector2(410, 36), 16, _data_font, PAPER)
	_labels.resources = _label("TREASURY  10     SOLIDARITY  60%     PRESSURE  24%", Vector2(465, 17), Vector2(480, 36), 16, _data_font, PAPER)
	_labels.docket_heading = _label("BONE & PICK / SHIFT DOCKET", Vector2(36, 98), Vector2(274, 38), 19, _display_font, COAL)
	_labels.worker_heading = _label("WORKERS                                      FAT", Vector2(37, 148), Vector2(270, 22), 11, _data_font, COAL)
	for index in 12:
		var button := Button.new()
		button.position = Vector2(34, 183 + index * 39)
		button.size = Vector2(278, 35)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", _body_font)
		button.add_theme_font_size_override("font_size", 13)
		button.set_meta("base_font_size", 13)
		button.set_meta("base_font", _body_font)
		button.set_meta("base_position", button.position)
		button.set_meta("base_size", button.size)
		button.add_theme_color_override("font_color", COAL)
		button.add_theme_color_override("font_pressed_color", PAPER)
		button.add_theme_color_override("font_focus_color", COAL)
		button.add_theme_stylebox_override("normal", _stylebox(Color(PAPER, 0.0), Color(COAL, 0.0), 0))
		button.add_theme_stylebox_override("hover", _stylebox(Color(BRASS, 0.22), BRASS.darkened(0.3), 1))
		button.add_theme_stylebox_override("pressed", _stylebox(UNION_RED, COAL, 2))
		button.add_theme_stylebox_override("focus", _stylebox(SAFETY_TEAL, COAL, 3))
		button.pressed.connect(_on_worker_pressed.bind(button))
		add_child(button)
		_worker_buttons.append(button)
	_labels.open_grievances = _label("OPEN GRIEVANCES", Vector2(37, 651), Vector2(270, 22), 11, _data_font, UNION_RED)
	_labels.grievances_list = _label("NO OPEN CASES", Vector2(37, 686), Vector2(270, 126), 11, _data_font, COAL)
	for index in 4:
		var incident_button := _button("", Vector2(34, 686 + index * 33), Vector2(278, 30))
		incident_button.toggle_mode = true
		incident_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		incident_button.add_theme_color_override("font_color", COAL)
		incident_button.add_theme_color_override("font_focus_color", COAL)
		incident_button.add_theme_stylebox_override("normal", _stylebox(Color(PAPER, 0.0), Color(COAL, 0.0), 0))
		incident_button.add_theme_stylebox_override("hover", _stylebox(Color(BRASS, 0.22), BRASS.darkened(0.3), 1))
		incident_button.visible = false
		incident_button.pressed.connect(_on_incident_pressed.bind(incident_button))
		_incident_buttons.append(incident_button)

	_labels.case_heading = _label("ACTIVE CASE FILE", Vector2(1132, 100), Vector2(250, 35), 19, _display_font, PAPER)
	_labels.case_title = _label("NO INCIDENT SELECTED", Vector2(1132, 153), Vector2(245, 54), 17, _display_font, BRASS)
	_labels.case_body = _label("Tab cycles active incidents.\nEvery alarm also appears here in writing.", Vector2(1132, 220), Vector2(238, 118), 14, _body_font, PAPER)
	_labels.grievance = _label("GRIEVANCE  —\nEVIDENCE   —", Vector2(1132, 350), Vector2(238, 44), 13, _data_font, SAFETY_TEAL)
	_labels.forecast = _label("DOCUMENT A CASE TO FORECAST", Vector2(1132, 401), Vector2(252, 72), 10, _data_font, PAPER)
	_labels.action = _label("", Vector2(1132, 638), Vector2(238, 112), 11, _body_font, PAPER)
	_document_button = _button("DOCUMENT TESTIMONY", Vector2(1132, 474), Vector2(238, 34))
	_document_button.pressed.connect(_request_primary_occurrence_action)
	var action_ids: Array[StringName] = [&"informal", &"grievance", &"petition", &"work_to_rule"]
	for index in action_ids.size():
		var action := action_ids[index]
		var action_button := _button(String(action).replace("_", " ").to_upper(), Vector2(1132 + (index % 2) * 122, 516 + int(index / 2) * 39), Vector2(116, 34))
		action_button.pressed.connect(_request_action.bind(action))
		_action_buttons.append(action_button)
	_remedy_button = _button("APPLY REMEDY / SETTLE", Vector2(1132, 598), Vector2(238, 34))
	_remedy_button.pressed.connect(_request_remedy)
	_negotiate_button = _button("ENTER NEGOTIATION  ›", Vector2(1132, 598), Vector2(238, 34))
	_negotiate_button.pressed.connect(func() -> void: command_requested.emit(WorkplaceCommandsScript.EnterNegotiationCommand.new()))
	_hall_button = _button("UNION HALL  ⌂", Vector2(1132, 758), Vector2(238, 42))
	_hall_button.pressed.connect(func() -> void: union_hall_requested.emit())

	_label("TIME", Vector2(960, 4), Vector2(50, 16), 10, _data_font, BRASS)
	for item in [["Ⅱ", true, 0], ["1×", false, 1], ["2×", false, 2], ["4×", false, 4]]:
		var speed_button := _button(item[0], Vector2(956 + int(item[2] if item[2] > 0 else 0) * 50, 27), Vector2(45, 30))
		if item[1]:
			speed_button.position.x = 956
			speed_button.pressed.connect(func() -> void: command_requested.emit(WorkplaceCommandsScript.PauseCommand.new(not bool(_view.get("paused", false)))))
		else:
			var speed := int(item[2])
			speed_button.position.x = 1010 + [1, 2, 4].find(speed) * 50
			speed_button.pressed.connect(func() -> void: command_requested.emit(WorkplaceCommandsScript.SetSpeedCommand.new(speed)))
	_save_button = _button("SAVE", Vector2(1205, 27), Vector2(95, 30))
	_save_button.name = "ManualSaveAction"
	_save_button.pressed.connect(func() -> void: command_requested.emit(WorkplaceCommandsScript.ManualSaveCommand.new()))
	_load_button = _button("LOAD", Vector2(1307, 27), Vector2(95, 30))
	_load_button.name = "ManualLoadAction"
	_load_button.pressed.connect(func() -> void: command_requested.emit(WorkplaceCommandsScript.ManualLoadCommand.new()))


func _update_case_file(view: Dictionary) -> void:
	var selected_id := StringName(view.get("selected_incident_id", &""))
	var selected: Dictionary = {}
	_remedy_button.disabled = true
	for incident in view.get("incidents", []):
		if StringName(incident.id) == selected_id:
			selected = incident
			break
	if selected.is_empty() and not view.get("incidents", []).is_empty():
		if selected_id != &"":
			selected = view.incidents[0]
	if selected.is_empty():
		var worker := _selected_worker(view)
		if worker.is_empty():
			_labels.case_title.text = "NO INCIDENT SELECTED"
			_labels.case_body.text = "Tab cycles active incidents.\nEvery alarm also appears here in writing."
		else:
			_labels.case_title.text = String(worker.get("display_name", worker.id))
			_labels.case_body.text = "%s  /  %s\nFATIGUE  %d\nTRUST  %d\nWILLING  %d\nPRIORITIES  %s" % [String(worker.get("species", &"worker")).capitalize(), String(worker.get("job_id", &"worker")).replace("_", " ").capitalize(), int(worker.get("fatigue", 0)), int(worker.get("trust", 0)), int(worker.get("action_willingness", 0)), _priority_copy(worker.get("bargaining_priorities", {}))]
		_labels.grievance.text = "GRIEVANCE  —\nEVIDENCE   —"
	else:
		var positive := StringName(selected.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND
		_labels.case_title.text = "%s  %s" % ["✦" if positive else "⚠", String(selected.get("title", selected.id)).to_upper()]
		_labels.case_body.text = "%s\n\nAFFECTED  %s\nPATTERN   %s" % [selected.get("description", "Workplace hazard requires attention."), ", ".join(selected.get("affected_workers", [])), selected.get("pattern", "///")]
		_labels.grievance.text = "POSITIVE EVENT\nNO GRIEVANCE OR EVIDENCE" if positive else "GRIEVANCE  %s\nEVIDENCE   %s\nSTEPS      %s" % [selected.get("grievance_phase", "reported"), selected.get("evidence_score", 0), " → ".join(selected.get("action_history", []))]
		_document_button.text = "ACKNOWLEDGE EVENT" if positive else "DOCUMENT TESTIMONY"
		for button in _action_buttons:
			button.disabled = positive
	_remedy_button.disabled = selected.is_empty() or StringName(selected.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND or selected.get("action_history", []).is_empty()
	var result: Dictionary = view.get("last_action_result", {})
	var action_lines: Array[String] = []
	var result_copy := String(result.get("summary", result.get("blocker", "")))
	if not result_copy.is_empty():
		action_lines.append(result_copy)
	var history: Array = view.get("incident_history", [])
	if not history.is_empty() and history[-1] is Dictionary:
		var latest: Dictionary = history[-1]
		var positive_history := StringName(latest.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND
		var history_status := String(latest.get("completion", &"acknowledged")) if positive_history else String(latest.get("grievance_phase", &"closed"))
		action_lines.append("RECENT HISTORY  %s — %s" % [String(latest.get("title", latest.get("id", &"event"))), history_status.to_upper()])
	_labels.action.text = "\n".join(action_lines)
	var forecast_lines: Array[String] = []
	if not selected.is_empty() and StringName(selected.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
		forecast_lines.append("ACKNOWLEDGE TO ADD TO HISTORY")
	else:
		_document_button.text = "DOCUMENT TESTIMONY"
		for button in _action_buttons:
			button.disabled = false
		for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
			var forecast: Dictionary = view.get("action_forecasts", {}).get(action, {})
			var status := "%d ready" % int(forecast.get("ready_count", 0)) if forecast.get("can_execute", false) else String(forecast.get("blocker", "document first")).left(25)
			forecast_lines.append("%-11s %s" % [String(action).replace("_", " ").to_upper(), status])
	_labels.forecast.text = "\n".join(forecast_lines)


func _on_worker_pressed(button: Button) -> void:
	command_requested.emit(WorkplaceCommandsScript.SelectWorkerCommand.new(StringName(button.get_meta("worker_id", &""))))


func _on_incident_pressed(button: Button) -> void:
	command_requested.emit(WorkplaceCommandsScript.InspectIncidentCommand.new(StringName(button.get_meta("incident_id", &""))))


func _selected_worker(view: Dictionary) -> Dictionary:
	var selected_id := StringName(view.get("selected_worker_id", &""))
	for worker in view.get("workers", []):
		if StringName(worker.id) == selected_id:
			return worker
	return {}


func _priority_copy(priorities: Dictionary) -> String:
	var parts: Array[String] = []
	for issue in priorities:
		parts.append("%s %d" % [String(issue).replace("_", " "), int(priorities[issue])])
	return ", ".join(parts)


func _build_scroll_regions() -> void:
	var controls: Array[Control] = []
	for child in get_children():
		if child is Control:
			controls.append(child)
	_create_scroll_region(Rect2(0, 0, 1440, 66), Vector2(1440, 66), controls.filter(func(control: Control) -> bool: return control.position.y < 66.0))
	_create_scroll_region(Rect2(18, 84, 310, 758), Vector2(310, 758), controls.filter(func(control: Control) -> bool: return control.position.x < 330.0 and control.position.y >= 66.0))
	_create_scroll_region(Rect2(1112, 84, 306, 758), Vector2(306, 758), controls.filter(func(control: Control) -> bool: return control.position.x >= 1112.0 and control.position.y >= 66.0))


func _create_scroll_region(rect: Rect2, base_size: Vector2, controls: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollRegion%02d" % _scroll_regions.size()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.clip_contents = true
	add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = base_size
	content.set_meta("base_size", base_size)
	scroll.add_child(content)
	for control in controls:
		var global_position: Vector2 = control.position
		remove_child(control)
		content.add_child(control)
		control.position = global_position - rect.position
	_scroll_regions.append(scroll)
	_scaled_contents.append(content)


func _build_panel_stacks() -> void:
	_left_stack = VBoxContainer.new()
	_left_stack.name = "WorkerGrievanceFlow"
	_left_stack.position = Vector2(16, 14)
	_left_stack.custom_minimum_size.x = 278
	_left_stack.add_theme_constant_override("separation", 4)
	_scaled_contents[1].add_child(_left_stack)
	_move_to_flow(_labels.docket_heading, _left_stack, 47, "DocketHeading")
	_move_to_flow(_labels.worker_heading, _left_stack, 31, "WorkerColumns")
	for index in _worker_buttons.size():
		_move_to_flow(_worker_buttons[index], _left_stack, 35, "WorkerRow%02d" % index)
	_move_to_flow(_labels.open_grievances, _left_stack, 31, "OpenGrievancesHeading")
	_move_to_flow(_labels.grievances_list, _left_stack, 31, "EmptyGrievanceState")
	for index in _incident_buttons.size():
		_move_to_flow(_incident_buttons[index], _left_stack, 30, "IncidentRow%02d" % index)

	_right_stack = VBoxContainer.new()
	_right_stack.name = "ContextCaseFlow"
	_right_stack.position = Vector2(20, 16)
	_right_stack.custom_minimum_size.x = 258
	_right_stack.add_theme_constant_override("separation", 7)
	_scaled_contents[2].add_child(_right_stack)
	_move_to_flow(_labels.case_heading, _right_stack, 35, "CaseHeading")
	_move_to_flow(_labels.case_title, _right_stack, 54, "CaseTitle")
	_move_to_flow(_labels.case_body, _right_stack, 118, "CaseNarrative")
	_move_to_flow(_labels.grievance, _right_stack, 44, "CaseEvidence")
	_move_to_flow(_labels.forecast, _right_stack, 72, "ActionForecast")
	_move_to_flow(_document_button, _right_stack, 34, "DocumentAction")
	_action_grid = GridContainer.new()
	_action_grid.name = "ActionChoices"
	_action_grid.columns = 2
	_action_grid.custom_minimum_size = Vector2(258, 73)
	_action_grid.add_theme_constant_override("h_separation", 6)
	_action_grid.add_theme_constant_override("v_separation", 5)
	_right_stack.add_child(_action_grid)
	for index in _action_buttons.size():
		_move_to_flow(_action_buttons[index], _action_grid, 34, "OrganizingAction%02d" % index, 126)
	_move_to_flow(_remedy_button, _right_stack, 34, "RemedyAction")
	_move_to_flow(_negotiate_button, _right_stack, 34, "NegotiateAction")
	_move_to_flow(_labels.action, _right_stack, 60, "ActionResult")
	_move_to_flow(_hall_button, _right_stack, 42, "UnionHallAction")
	for button in find_children("*", "Button", true, false):
		button.focus_entered.connect(_on_focus_entered.bind(button))
	_refresh_focus_neighbors()


func _move_to_flow(control: Control, container: Container, minimum_height: float, control_name: String, minimum_width: float = 0.0) -> void:
	var parent := control.get_parent()
	parent.remove_child(control)
	container.add_child(control)
	control.name = control_name
	control.position = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flow_minimum := Vector2(minimum_width, minimum_height)
	control.set_meta("flow_minimum_size", flow_minimum)
	control.custom_minimum_size.y = minimum_height
	if minimum_width > 0.0:
		control.custom_minimum_size.x = minimum_width


func _settle_panel_layout() -> void:
	_reserve_label_height(_labels.docket_heading, 47)
	_reserve_label_height(_labels.worker_heading, 31)
	_reserve_label_height(_labels.open_grievances, 31)
	_reserve_label_height(_labels.case_title, 54)
	_reserve_label_height(_labels.case_body, 118)
	_reserve_label_height(_labels.grievance, 44)
	_reserve_label_height(_labels.forecast, 72)
	_reserve_label_height(_labels.action, 60)
	_refresh_flow_extent(1, _left_stack)
	_refresh_flow_extent(2, _right_stack)


func _reserve_label_height(label: Label, baseline: float) -> void:
	var line_height := maxi(1, label.get_line_height())
	var narrative_height := float(maxi(1, label.get_line_count()) * line_height) + 8.0 * _settings.ui_scale
	label.custom_minimum_size.y = maxf(baseline * _settings.ui_scale, narrative_height)


func _refresh_flow_extent(content_index: int, stack: VBoxContainer) -> void:
	var content := _scaled_contents[content_index]
	var base_size: Vector2 = content.get_meta("base_size")
	var stack_extent := stack.size.max(stack.get_combined_minimum_size())
	var edge_margin := 16.0 * _settings.ui_scale
	content.custom_minimum_size = Vector2(
		maxf(_scroll_regions[content_index].size.x, stack.position.x + stack_extent.x + edge_margin),
		maxf(base_size.y * _settings.ui_scale, stack.position.y + stack.get_combined_minimum_size().y + 16.0 * _settings.ui_scale)
	)


func _layout_control_rects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region_index in _scroll_regions.size():
		var region_rect := _scroll_regions[region_index].get_global_rect()
		for control in _scaled_contents[region_index].find_children("*", "Control", true, false):
			if not control is Label and not control is Button:
				continue
			if not control.is_visible_in_tree():
				continue
			var transformed := _transformed_control_rect(control)
			result.append({
				"name": String(control.name),
				"region": region_index,
				"rect": transformed,
				"visible_rect": transformed.intersection(region_rect),
			})
	return result


func _scale_container(container: VBoxContainer, base_position: Vector2, base_width: float, base_separation: int) -> void:
	if container == null:
		return
	container.position = base_position * _settings.ui_scale
	container.custom_minimum_size.x = base_width * _settings.ui_scale
	container.add_theme_constant_override("separation", maxi(1, int(round(float(base_separation) * _settings.ui_scale))))


func _on_focus_entered(control: Control) -> void:
	call_deferred(&"_ensure_focus_visible", control)


func _ensure_focus_visible(control: Control) -> void:
	var current: Node = control.get_parent()
	while current != null:
		if current is ScrollContainer:
			(current as ScrollContainer).ensure_control_visible(control)
			return
		current = current.get_parent()


func _focus_sequence() -> Array[Button]:
	var sequence: Array[Button] = []
	for button in _worker_buttons:
		if button.visible and not button.disabled:
			sequence.append(button)
	for button in _incident_buttons:
		if button.visible and not button.disabled:
			sequence.append(button)
	for button in [_document_button, _action_buttons[0], _action_buttons[1], _action_buttons[2], _action_buttons[3], _remedy_button, _negotiate_button, _hall_button, _save_button, _load_button]:
		if button != null and button.visible and not button.disabled:
			sequence.append(button)
	return sequence


func _refresh_focus_neighbors() -> void:
	var sequence := _focus_sequence()
	if sequence.is_empty():
		return
	for index in sequence.size():
		var button := sequence[index]
		var previous := sequence[posmod(index - 1, sequence.size())]
		var next := sequence[(index + 1) % sequence.size()]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_previous = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_next = button.get_path_to(next)


func _transformed_control_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0),
		transform * control.size,
		transform * Vector2(0, control.size.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for point in corners.slice(1):
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _request_action(action: StringName) -> void:
	var incidents: Array = _view.get("incidents", [])
	if incidents.is_empty():
		return
	var selected_id := StringName(_view.get("selected_incident_id", incidents[0].id))
	command_requested.emit(WorkplaceCommandsScript.ProposeActionCommand.new(action, selected_id))


func _request_primary_occurrence_action() -> void:
	var incidents: Array = _view.get("incidents", [])
	if incidents.is_empty():
		return
	var selected_id := StringName(_view.get("selected_incident_id", incidents[0].id))
	for occurrence in incidents:
		if StringName(occurrence.get("id", &"")) != selected_id:
			continue
		if StringName(occurrence.get("event_kind", &"grievance")) == EventDefinition.POSITIVE_KIND:
			command_requested.emit(WorkplaceCommandsScript.AcknowledgeEventCommand.new(selected_id))
			return
	_request_action(&"document")


func _request_remedy() -> void:
	var incidents: Array = _view.get("incidents", [])
	if incidents.is_empty():
		return
	var selected_id := StringName(_view.get("selected_incident_id", incidents[0].id))
	command_requested.emit(WorkplaceCommandsScript.ApplyRemedyCommand.new(selected_id, &"settlement"))


func _label(text: String, position: Vector2, size: Vector2, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font_size", font_size)
	label.set_meta("base_font", font)
	label.set_meta("base_position", position)
	label.set_meta("base_size", size)
	add_child(label)
	return label


func _button(text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _data_font)
	button.add_theme_font_size_override("font_size", 12)
	button.set_meta("base_font_size", 12)
	button.set_meta("base_font", _data_font)
	button.set_meta("base_position", position)
	button.set_meta("base_size", size)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_focus_color", COAL)
	button.add_theme_stylebox_override("normal", _stylebox(COAL.lightened(0.06), BRASS.darkened(0.35), 1))
	button.add_theme_stylebox_override("hover", _stylebox(SLATE.lightened(0.13), BRASS, 2))
	button.add_theme_stylebox_override("pressed", _stylebox(UNION_RED, PAPER, 2))
	button.add_theme_stylebox_override("focus", _stylebox(SAFETY_TEAL, COAL, 3))
	add_child(button)
	return button


func _stylebox(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(result[0])
	return result


func _species_symbol(species: StringName) -> String:
	match species:
		&"skeleton": return "◇"
		&"imp": return "▲"
		&"kobold": return "◆"
		&"bugbear": return "■"
		&"hobgoblin": return "⬟"
		_: return "●"
