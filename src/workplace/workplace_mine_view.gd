class_name WorkplaceMineView
extends Node2D

const COAL := Color("0b1114")
const SLATE := Color("16242b")
const PAPER := Color("e8d9b5")
const BRASS := Color("d2a75c")
const UNION_RED := Color("a54138")
const SAFETY_TEAL := Color("79b7b0")

const WORKER_POSITIONS: Array[Vector2] = [
	Vector2(-250, -75), Vector2(-125, -142), Vector2(10, -74), Vector2(146, -142),
	Vector2(265, -72), Vector2(-195, 20), Vector2(-68, -45), Vector2(68, 22),
	Vector2(198, -38), Vector2(-128, 105), Vector2(8, 92), Vector2(142, 112),
]

var _catalog: ContentCatalog
var _worker_nodes: Dictionary[StringName, Node2D] = {}
var _selected_worker_id: StringName = &""
var _selected_incident_id: StringName = &""
var _incident_views: Array[Dictionary] = []
var _high_contrast := false
var _reduced_motion := false
var _elapsed := 0.0
var _body_font: SystemFont


func configure(catalog: ContentCatalog) -> void:
	_catalog = catalog
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue", "Arial"])
	_build_worker_tokens()
	queue_redraw()


func update_view(view: Dictionary) -> void:
	_selected_worker_id = StringName(view.get("selected_worker_id", &""))
	_selected_incident_id = StringName(view.get("selected_incident_id", &""))
	_incident_views.clear()
	for incident in view.get("incidents", []):
		if StringName(incident.get("grievance_phase", &"reported")) != &"resolved":
			_incident_views.append(incident.duplicate(true))
	for worker_id in _worker_nodes:
		var token: Node2D = _worker_nodes[worker_id]
		var ring: Polygon2D = token.get_node("SelectionRing")
		ring.visible = worker_id == _selected_worker_id
	queue_redraw()


func set_accessibility(settings: AccessibilitySettings) -> void:
	_high_contrast = settings.high_contrast
	_reduced_motion = settings.reduced_motion
	if _body_font != null:
		_body_font.font_names = PackedStringArray(
			["Atkinson Hyperlegible", "Arial", "Helvetica"]
			if settings.dyslexia_friendly_font
			else ["Avenir Next", "Avenir", "Helvetica Neue", "Arial"]
		)
		for token in _worker_nodes.values():
			var nameplate: Label = token.get_child(token.get_child_count() - 1)
			nameplate.add_theme_font_override("font", _body_font)
			nameplate.add_theme_font_size_override("font_size", maxi(12, int(12.0 * settings.ui_scale)))
	queue_redraw()


func _process(delta: float) -> void:
	if _reduced_motion:
		return
	_elapsed += delta
	for worker_id in _worker_nodes:
		var token: Node2D = _worker_nodes[worker_id]
		var base_y := float(token.get_meta("base_y", token.position.y))
		var phase := float(token.get_meta("phase", 0.0))
		token.position.y = base_y + sin(_elapsed * 1.4 + phase) * 1.5


func _draw() -> void:
	# Fixed-orientation isometric mine floor: every large shape shares the same 2:1 diamond.
	for cell_y in 5:
		for cell_x in 7:
			var center := Vector2((cell_x - cell_y) * 82.0, (cell_x + cell_y) * 41.0 - 235.0)
			var shade := SLATE.lightened(0.035 if (cell_x + cell_y) % 2 == 0 else 0.0)
			draw_colored_polygon(_diamond(center, 82.0, 41.0), shade)
			draw_polyline(_closed(_diamond(center, 82.0, 41.0)), COAL.lightened(0.15), 1.4, true)

	# Excavation faces and timber shoring make the greybox read as a working mine.
	_draw_wall(Vector2(-410, -44), Vector2(-164, -167), 92.0)
	_draw_wall(Vector2(246, -167), Vector2(410, -84), 90.0)
	for x in [-315.0, -151.0, 176.0, 340.0]:
		draw_line(Vector2(x, -142), Vector2(x, -35), BRASS.darkened(0.28), 10.0)
		draw_line(Vector2(x - 22, -129), Vector2(x + 22, -151), BRASS, 5.0)

	# Lantern-fume hazard uses both teal and repeated diagonal hatching.
	var hazard := PackedVector2Array([Vector2(-54, -30), Vector2(100, 47), Vector2(34, 81), Vector2(-120, 4)])
	draw_colored_polygon(hazard, Color(SAFETY_TEAL, 0.16 if not _high_contrast else 0.34))
	draw_polyline(_closed(hazard), PAPER if _high_contrast else SAFETY_TEAL, 3.0, true)
	for offset in range(-80, 81, 16):
		draw_line(Vector2(-75 + offset, 8), Vector2(-29 + offset, 54), Color(SAFETY_TEAL, 0.65), 2.0)
	draw_string(_body_font, Vector2(-49, 3), "///  FUME WATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)

	# Cart rail and alarm post provide distinct landmarks at all zoom levels.
	draw_polyline(PackedVector2Array([Vector2(-322, 111), Vector2(-90, 225), Vector2(260, 50)]), BRASS.darkened(0.35), 12.0, true)
	draw_polyline(PackedVector2Array([Vector2(-322, 111), Vector2(-90, 225), Vector2(260, 50)]), BRASS, 3.0, true)
	draw_circle(Vector2(302, -93), 25.0, UNION_RED.darkened(0.25))
	draw_arc(Vector2(302, -93), 18.0, 0.0, TAU, 24, PAPER, 3.0)
	draw_string(_body_font, Vector2(282, -88), "!", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 21, PAPER)
	_draw_incident_markers()


func _draw_incident_markers() -> void:
	if _incident_views.is_empty():
		return
	if scale.x < 0.86 and _incident_views.size() > 1:
		_draw_incident_marker(Vector2(35, -12), _incident_views[0], "%d ACTIVE" % _incident_views.size(), true)
		return
	for index in _incident_views.size():
		var incident: Dictionary = _incident_views[index]
		_draw_incident_marker(_incident_position(StringName(incident.id), index), incident, String(incident.get("pattern", "!!!")).left(3), StringName(incident.id) == _selected_incident_id)


func _draw_incident_marker(position: Vector2, incident: Dictionary, marker_text: String, selected: bool) -> void:
	var marker := PackedVector2Array([
		position + Vector2(0, -34), position + Vector2(29, 18), position + Vector2(-29, 18),
	])
	draw_colored_polygon(marker, UNION_RED if selected else BRASS)
	draw_polyline(_closed(marker), PAPER if _high_contrast or selected else COAL, 4.0 if selected else 2.0, true)
	draw_string(_body_font, position + Vector2(-25, 8), marker_text, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 11, COAL)
	var affected: Array = incident.get("affected_workers", [])
	if not affected.is_empty():
		draw_string(_body_font, position + Vector2(-55, 38), "↳ %s" % ", ".join(affected), HORIZONTAL_ALIGNMENT_CENTER, 110.0, 11, PAPER)


func _incident_position(event_id: StringName, fallback_index: int) -> Vector2:
	match event_id:
		&"cave_in_risk": return Vector2(-290, -120)
		&"lantern_fumes": return Vector2(-5, -32)
		&"unpaid_maintenance": return Vector2(180, 70)
		&"adventurer_alarm": return Vector2(302, -122)
		&"foreman_intimidation": return Vector2(165, 20)
		&"spontaneous_mutual_aid": return Vector2(-110, 145)
		_: return Vector2(-230 + fallback_index * 92, 42)


func _build_worker_tokens() -> void:
	for child in get_children():
		child.queue_free()
	_worker_nodes.clear()
	if _catalog == null:
		return
	var workers := _catalog.worker_items
	for index in mini(workers.size(), WORKER_POSITIONS.size()):
		var definition: WorkerDefinition = workers[index]
		var token := Node2D.new()
		token.name = "Worker_%s" % definition.id
		token.position = WORKER_POSITIONS[index]
		token.set_meta("base_y", token.position.y)
		token.set_meta("phase", index * 0.47)

		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([Vector2(-19, 13), Vector2(0, 23), Vector2(19, 13), Vector2(0, 4)])
		shadow.color = Color(COAL, 0.72)
		token.add_child(shadow)

		var ring := Polygon2D.new()
		ring.name = "SelectionRing"
		ring.polygon = PackedVector2Array([Vector2(-27, 4), Vector2(0, 20), Vector2(27, 4), Vector2(0, -12)])
		ring.color = UNION_RED
		ring.visible = false
		token.add_child(ring)

		var body := Polygon2D.new()
		body.polygon = _worker_shape(definition.species)
		body.color = _worker_color(index)
		token.add_child(body)

		var badge := Label.new()
		badge.position = Vector2(-8, -31)
		badge.text = _species_symbol(definition.species)
		badge.add_theme_font_override("font", _body_font)
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", COAL)
		token.add_child(badge)

		var nameplate := Label.new()
		nameplate.position = Vector2(-62, 25)
		nameplate.size = Vector2(124, 24)
		nameplate.text = definition.display_name
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate.add_theme_font_override("font", _body_font)
		nameplate.add_theme_font_size_override("font_size", 12)
		nameplate.add_theme_color_override("font_color", PAPER)
		nameplate.add_theme_color_override("font_outline_color", COAL)
		nameplate.add_theme_constant_override("outline_size", 4)
		nameplate.tooltip_text = "%s, %s %s" % [definition.display_name, definition.species, definition.job_id]
		token.add_child(nameplate)

		add_child(token)
		_worker_nodes[definition.id] = token


func _draw_wall(from: Vector2, to: Vector2, height: float) -> void:
	var wall := PackedVector2Array([from, to, to - Vector2(0, height), from - Vector2(0, height)])
	draw_colored_polygon(wall, COAL.lightened(0.08))
	draw_polyline(_closed(wall), BRASS.darkened(0.45), 2.0, true)
	for step in 5:
		var point := from.lerp(to, float(step) / 4.0)
		draw_line(point, point - Vector2(0, height), Color(PAPER, 0.11), 2.0)


func _diamond(center: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_height), center + Vector2(half_width, 0),
		center + Vector2(0, half_height), center + Vector2(-half_width, 0),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


func _worker_shape(species: StringName) -> PackedVector2Array:
	match species:
		&"skeleton":
			return PackedVector2Array([Vector2(-16, 9), Vector2(-8, -19), Vector2(0, -27), Vector2(8, -19), Vector2(16, 9), Vector2(0, 18)])
		&"imp":
			return PackedVector2Array([Vector2(-21, 8), Vector2(-15, -15), Vector2(-4, -25), Vector2(0, -16), Vector2(9, -27), Vector2(18, 7), Vector2(0, 18)])
		&"kobold":
			return PackedVector2Array([Vector2(-17, 10), Vector2(-12, -16), Vector2(0, -27), Vector2(15, -15), Vector2(18, 10), Vector2(0, 19)])
		_:
			return PackedVector2Array([Vector2(-18, 9), Vector2(-14, -17), Vector2(-6, -25), Vector2(0, -18), Vector2(8, -27), Vector2(16, -15), Vector2(18, 9), Vector2(0, 19)])


func _worker_color(index: int) -> Color:
	return [PAPER, BRASS, SAFETY_TEAL, UNION_RED.lightened(0.18)][index % 4]


func _species_symbol(species: StringName) -> String:
	match species:
		&"skeleton": return "◇"
		&"imp": return "▲"
		&"kobold": return "◆"
		&"bugbear": return "■"
		&"hobgoblin": return "⬟"
		_: return "●"
