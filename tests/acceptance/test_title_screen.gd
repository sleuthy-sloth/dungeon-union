extends RefCounted


static func run(t: TestCase) -> void:
	_title_key_art_is_versioned(t)


static func _title_key_art_is_versioned(t: TestCase) -> void:
	var path := "res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png"
	t.check(FileAccess.file_exists(path), "title key art is versioned")
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		t.check(not image.is_empty(), "title key art is a readable PNG")
		if image.is_empty():
			return
		t.check(image.get_width() > image.get_height(), "title key art is landscape")
