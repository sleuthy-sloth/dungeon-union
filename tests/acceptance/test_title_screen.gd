extends RefCounted


static func run(t: TestCase) -> void:
	_title_key_art_is_versioned(t)
	_title_actions_are_focusable_and_semantic(t)
	_app_root_waits_for_a_title_action(t)


static func _title_key_art_is_versioned(t: TestCase) -> void:
	var path := "res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png"
	t.check(FileAccess.file_exists(path), "title key art is versioned")
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		t.check(not image.is_empty(), "title key art is a readable PNG")
		if image.is_empty():
			return
		t.check(image.get_width() > image.get_height(), "title key art is landscape")


static func _title_actions_are_focusable_and_semantic(t: TestCase) -> void:
	var path := "res://src/ui/title_screen.tscn"
	t.check(ResourceLoader.exists(path), "title scene is available")
	if not ResourceLoader.exists(path):
		return
	var title: Control = load(path).instantiate()
	t.check(title.has_node("ContinueShift"), "title exposes Continue Shift")
	t.check(title.has_node("NewShift"), "title exposes New Shift")
	t.check(title.has_node("Accessibility"), "title exposes Accessibility")
	var new_shift: Button = title.get_node_or_null("NewShift")
	t.check(new_shift != null and new_shift.focus_mode == Control.FOCUS_ALL, "New Shift supports keyboard focus")
	title.free()


static func _app_root_waits_for_a_title_action(t: TestCase) -> void:
	var app: AppRoot = load("res://src/app/app_root.tscn").instantiate()
	t.check(app.has_node("TitleScreen"), "app root includes the title screen")
	app.free()
