class_name UnionHallView
extends Control

signal closed

const COAL := Color("0b1114")
const SLATE := Color("16242b")
const PAPER := Color("e8d9b5")
const BRASS := Color("d2a75c")
const UNION_RED := Color("a54138")
const SAFETY_TEAL := Color("79b7b0")

const BRANCH_COPY: Dictionary[StringName, Dictionary] = {
	&"steward_school": {"title": "STEWARD SCHOOL", "symbol": "✦", "copy": "Delegate routine listening and strengthen local leadership."},
	&"legal_desk": {"title": "LEGAL DESK", "symbol": "§", "copy": "Preserve evidence and surface approaching deadlines."},
	&"mutual_aid_kitchen": {"title": "MUTUAL-AID KITCHEN", "symbol": "♨", "copy": "Lower fatigue and keep workers steady through a crisis."},
	&"print_shop": {"title": "PRINT SHOP", "symbol": "▤", "copy": "Build public support and answer the foreman's rumors."},
	&"organizing_workshop": {"title": "ORGANIZING WORKSHOP", "symbol": "⚒", "copy": "Clarify participation forecasts and advanced actions."},
}

var _campaign: CampaignState
var _buttons: Dictionary[StringName, Button] = {}
var _points_label: Label
var _display_font: SystemFont
var _body_font: SystemFont
var _data_font: SystemFont
var _accessible_font: SystemFont
var _settings := AccessibilitySettings.new()
var _scroll: ScrollContainer
var _content: Control
var _close_button: Button


func _ready() -> void:
	_build_fonts()
	_build_controls()
	_build_scroll_content()
	queue_redraw()


func configure(campaign: CampaignState) -> void:
	_campaign = campaign
	_refresh()


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


func close_view() -> void:
	visible = false
	closed.emit()


func set_accessibility(settings: AccessibilitySettings) -> void:
	_settings = settings.normalized_copy()
	scale = Vector2.ONE
	if _content != null:
		_content.scale = Vector2.ONE
		_content.custom_minimum_size = Vector2(1440, 900) * _settings.ui_scale
	for child in find_children("*", "Control", true, false):
		if child.has_meta("base_font_size"):
			child.add_theme_font_size_override("font_size", maxi(1, int(round(float(child.get_meta("base_font_size")) * _settings.ui_scale))))
			var base_font: Font = child.get_meta("base_font")
			child.add_theme_font_override("font", _accessible_font if _settings.dyslexia_friendly_font else base_font)
		if child.has_meta("base_position") and child.has_meta("base_size"):
			child.position = Vector2(child.get_meta("base_position")) * _settings.ui_scale
			child.size = Vector2(child.get_meta("base_size")) * _settings.ui_scale
	queue_redraw()


func accessibility_layout_view() -> Dictionary:
	var all_inside := _scroll != null and Rect2(Vector2.ZERO, Vector2(1440, 900)).encloses(_scroll.get_rect())
	var no_intersections := true
	var focus_outlines := true
	var controls: Array[Control] = []
	if _content != null:
		for child in _content.get_children():
			if child is Control and child.visible:
				controls.append(child)
				if child is Button:
					focus_outlines = focus_outlines and child.focus_mode == Control.FOCUS_ALL and child.has_theme_stylebox_override("focus")
		for left_index in controls.size():
			for right_index in range(left_index + 1, controls.size()):
				no_intersections = no_intersections and not controls[left_index].get_rect().intersects(controls[right_index].get_rect())
	return {
		"all_inside_viewport": all_inside,
		"no_intersections": no_intersections,
		"focus_outlines": focus_outlines,
		"scrollable_reflow": _content != null and _content.custom_minimum_size.x >= 1440.0 * _settings.ui_scale,
		"high_contrast": _settings.high_contrast,
		"reduced_motion": _settings.reduced_motion,
		"dyslexia_friendly_font": _settings.dyslexia_friendly_font,
		"body_font_size": maxi(1, int(round(12.0 * _settings.ui_scale))),
		"content_extent": _content.custom_minimum_size if _content != null else Vector2.ZERO,
	}


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color(COAL, 0.96))
	# A compact isometric union hall under warm communal light.
	var floor := PackedVector2Array([Vector2(470, 180), Vector2(1020, 455), Vector2(720, 605), Vector2(170, 330)])
	draw_colored_polygon(floor, SLATE)
	draw_polyline(_closed(floor), PAPER if _settings.high_contrast else BRASS, 4.0, true)
	for step in 7:
		var a := Vector2(470, 180).lerp(Vector2(170, 330), float(step) / 6.0)
		var b := Vector2(1020, 455).lerp(Vector2(720, 605), float(step) / 6.0)
		draw_line(a, b, Color(PAPER, 0.09), 2.0)
	# Union-red thread binds the five branch stations into one organization.
	var thread := PackedVector2Array([Vector2(250, 690), Vector2(475, 645), Vector2(720, 690), Vector2(965, 645), Vector2(1190, 690)])
	draw_polyline(thread, UNION_RED, 7.0, true)
	for point in thread:
		draw_circle(point, 10.0, UNION_RED)
		draw_arc(point, 14.0, 0, TAU, 24, PAPER, 2.0)
	# Pamphlet heading band.
	draw_colored_polygon(PackedVector2Array([Vector2(150, 76), Vector2(1110, 76), Vector2(1150, 116), Vector2(1110, 156), Vector2(150, 156)]), PAPER)
	draw_line(Vector2(150, 159), Vector2(1110, 159), UNION_RED, 5.0)


func _build_fonts() -> void:
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Palatino", "Book Antiqua", "Times New Roman"])
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue", "Arial"])
	_data_font = SystemFont.new()
	_data_font.font_names = PackedStringArray(["Menlo", "Monaco", "Courier New"])
	_accessible_font = SystemFont.new()
	_accessible_font.font_names = PackedStringArray(["Atkinson Hyperlegible", "Arial", "Helvetica"])


func _build_controls() -> void:
	var title := _label("LOCAL 666  /  UNION HALL", Vector2(184, 88), Vector2(660, 56), 29, _display_font, COAL)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_label = _label("UPGRADE POINTS  05", Vector2(906, 96), Vector2(190, 35), 14, _data_font, COAL)
	_close_button = _button("RETURN TO MINE  ×", Vector2(1190, 92), Vector2(196, 42))
	_close_button.name = "ReturnToMineAction"
	_close_button.pressed.connect(close_view)
	var index := 0
	for branch in BRANCH_COPY:
		var copy: Dictionary = BRANCH_COPY[branch]
		var x := 132 + index * 257
		_label("%s  %s" % [copy.symbol, copy.title], Vector2(x, 660), Vector2(224, 32), 15, _display_font, PAPER)
		_label(copy.copy, Vector2(x, 703), Vector2(224, 70), 12, _body_font, PAPER)
		var button := _button("INSTALL  /  1 POINT", Vector2(x, 786), Vector2(224, 42))
		button.name = "Upgrade_%s" % branch
		button.set_meta("upgrade_branch", branch)
		button.pressed.connect(_on_upgrade_pressed.bind(branch))
		_buttons[branch] = button
		index += 1


func _build_scroll_content() -> void:
	var controls: Array[Control] = []
	for child in get_children():
		if child is Control:
			controls.append(child)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.clip_contents = true
	add_child(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(1440, 900)
	_scroll.add_child(_content)
	for control in controls:
		remove_child(control)
		_content.add_child(control)
	for button in _content.find_children("*", "Button", true, false):
		button.focus_entered.connect(_on_focus_entered.bind(button))
	_refresh_focus_neighbors()


func _on_focus_entered(control: Control) -> void:
	call_deferred(&"_ensure_focus_visible", control)


func _ensure_focus_visible(control: Control) -> void:
	if _scroll != null:
		_scroll.ensure_control_visible(control)


func _on_upgrade_pressed(branch: StringName) -> void:
	if _campaign != null:
		_campaign.apply_command(ApplyUpgradeCommand.new(branch, 1))
	_refresh()


func _refresh() -> void:
	if _campaign == null or not is_node_ready():
		return
	var view := _campaign.read_view()
	_points_label.text = "UPGRADE POINTS  %02d" % int(view.upgrade_points)
	for branch in _buttons:
		var purchased: bool = view.upgrades.has(StringName("%s_1" % branch))
		var button: Button = _buttons[branch]
		button.disabled = purchased or int(view.upgrade_points) == 0
		button.text = "INSTALLED  ✓" if purchased else "INSTALL  /  1 POINT"
	_refresh_focus_neighbors()


func _focus_sequence() -> Array[Button]:
	var sequence: Array[Button] = []
	for branch in CampaignState.BRANCHES:
		var button: Button = _buttons.get(branch)
		if button != null and button.visible and not button.disabled:
			sequence.append(button)
	if _close_button != null and _close_button.visible:
		sequence.append(_close_button)
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
