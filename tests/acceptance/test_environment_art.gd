extends RefCounted


static func run(t: TestCase) -> void:
	_blender_source_is_versioned(t)
	_valid_manifest_describes_renderable_isometric_layers(t)
	_lantern_flicker_export_is_complete(t)
	_missing_or_malformed_manifest_is_rejected(t)
	_mine_view_assembles_art_without_hiding_workers(t)



static func _blender_source_is_versioned(t: TestCase) -> void:
	t.check(FileAccess.file_exists("res://art/blender/scripts/build_bone_and_pick.py"), "Blender environment builder is versioned")
	t.check(FileAccess.file_exists("res://art/blender/bone_and_pick_environment.blend"), "editable Blender source scene is versioned")


static func _valid_manifest_describes_renderable_isometric_layers(t: TestCase) -> void:
	var script_path := "res://src/workplace/environment_art_manifest.gd"
	if not ResourceLoader.exists(script_path):
		t.check(false, "environment art manifest parser is available")
		return
	var parser_script: GDScript = load(script_path)
	var manifest: Variant = parser_script.load_from_path("res://assets/environment/bone_and_pick/manifest.json")
	t.check(manifest.is_valid(), "Bone & Pick environment manifest is valid: %s" % manifest.errors)
	if not manifest.is_valid():
		return
	t.equal(manifest.layer_ids(), PackedStringArray(["ground", "midground", "structure", "foreground"]), "environment renders retain the required back-to-front order")
	for layer: Dictionary in manifest.layers:
		var image := Image.load_from_file("res://assets/environment/bone_and_pick/%s" % String(layer.file))
		t.check(not image.is_empty(), "%s layer is a readable PNG" % String(layer.id))
		t.equal(image.get_size(), manifest.canvas_size, "%s layer uses the shared canvas" % String(layer.id))
		t.equal(image.get_format(), Image.FORMAT_RGBA8, "%s layer preserves an RGBA canvas" % String(layer.id))


static func _lantern_flicker_export_is_complete(t: TestCase) -> void:
	var manifest_path := "res://assets/effects/lantern_flicker/manifest.json"
	t.check(FileAccess.file_exists("res://art/blender/scripts/render_lantern_flicker.py"), "Blender lantern loop builder is versioned")
	t.check(FileAccess.file_exists(manifest_path), "lantern loop manifest is exported")
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	t.check(parsed is Dictionary, "lantern loop manifest is readable JSON")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	t.equal(int(manifest.get("fps", 0)), 8, "lantern loop uses a gentle eight-frame cadence")
	var frames: Array = manifest.get("frames", [])
	t.equal(frames.size(), 6, "lantern loop has six authored frames")
	for frame_name: Variant in frames:
		var image := Image.load_from_file("res://assets/effects/lantern_flicker/%s" % String(frame_name))
		t.check(not image.is_empty(), "%s lantern frame is readable" % String(frame_name))
		if not image.is_empty():
			t.equal(image.get_size(), Vector2i(256, 256), "%s lantern frame has the shared canvas" % String(frame_name))
			t.equal(image.get_format(), Image.FORMAT_RGBA8, "%s lantern frame keeps alpha" % String(frame_name))


static func _missing_or_malformed_manifest_is_rejected(t: TestCase) -> void:
	var script_path := "res://src/workplace/environment_art_manifest.gd"
	if not ResourceLoader.exists(script_path):
		return
	var parser_script: GDScript = load(script_path)
	var manifest: Variant = parser_script.load_from_path("res://tests/fixtures/missing-environment-manifest.json")
	t.check(not manifest.is_valid(), "malformed environment manifest is rejected without crashing")


static func _mine_view_assembles_art_without_hiding_workers(t: TestCase) -> void:
	var mine := WorkplaceMineView.new()
	mine.configure(load("res://content/bone_and_pick/catalog.tres"))
	t.check(mine.environment_art_loaded(), "valid environment art replaces the procedural mine background")
	t.equal(mine.environment_art_layer_names(), PackedStringArray(["ground", "midground", "structure", "foreground"]), "mine view uses the manifest layer order")
	var foreground: Sprite2D = mine.get_node_or_null("EnvironmentArt/foreground")
	var environment_art: Node2D = mine.get_node_or_null("EnvironmentArt")
	var lantern: AnimatedSprite2D = mine.get_node_or_null("EnvironmentArt/LanternFlicker")
	var worker: Node2D = mine.get_node_or_null("Worker_nib")
	t.check(foreground != null and worker != null and foreground.z_index < worker.z_index, "environment foreground remains below worker interactions")
	t.check(environment_art != null and not environment_art.is_queued_for_deletion(), "worker rebuild retains the environment art container")
	t.check(lantern != null and lantern.is_playing() and lantern.sprite_frames.get_frame_count(&"flicker") == 6, "rendered lantern frames play in the mine")
	mine.free()
