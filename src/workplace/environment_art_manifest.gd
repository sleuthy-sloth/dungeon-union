class_name EnvironmentArtManifest
extends RefCounted

static var REQUIRED_LAYER_IDS := PackedStringArray(["ground", "midground", "structure", "foreground"])

var canvas_size := Vector2i.ZERO
var world_anchor := Vector2.ZERO
var layers: Array[Dictionary] = []
var errors := PackedStringArray()


static func load_from_path(path: String) -> EnvironmentArtManifest:
	var result: EnvironmentArtManifest = load("res://src/workplace/environment_art_manifest.gd").new()
	if not FileAccess.file_exists(path):
		result.errors.append("Manifest does not exist: %s" % path)
		return result
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		result.errors.append("Manifest is not a JSON object: %s" % path)
		return result
	result._read(Dictionary(json.data), path.get_base_dir())
	return result


func is_valid() -> bool:
	return errors.is_empty()


func layer_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for layer in layers:
		ids.append(String(layer.id))
	return ids


func _read(data: Dictionary, directory: String) -> void:
	if data.get("schema_version") != 1:
		errors.append("Manifest schema_version must be 1")
		return
	var canvas: Variant = data.get("canvas_size")
	if not _is_positive_integer_pair(canvas):
		errors.append("Manifest canvas_size must contain two positive integers")
		return
	canvas_size = Vector2i(int(canvas[0]), int(canvas[1]))
	var anchor: Variant = data.get("world_anchor")
	if not _is_number_pair(anchor):
		errors.append("Manifest world_anchor must contain two numbers")
		return
	world_anchor = Vector2(float(anchor[0]), float(anchor[1]))
	var source_layers: Variant = data.get("layers")
	if not source_layers is Array or source_layers.size() != REQUIRED_LAYER_IDS.size():
		errors.append("Manifest must contain exactly four layers")
		return
	for index in source_layers.size():
		var source_layer: Variant = source_layers[index]
		if not source_layer is Dictionary:
			errors.append("Layer %d is not an object" % index)
			return
		var layer_data := Dictionary(source_layer)
		var expected_id := REQUIRED_LAYER_IDS[index]
		if String(layer_data.get("id", "")) != expected_id:
			errors.append("Layer %d must be %s" % [index, expected_id])
			return
		var file := String(layer_data.get("file", ""))
		if file.is_empty() or not file.ends_with(".png"):
			errors.append("Layer %s must name a PNG file" % expected_id)
			return
		if not _is_whole_number(layer_data.get("z_index")):
			errors.append("Layer %s must define an integer z_index" % expected_id)
			return
		var layer_anchor: Variant = layer_data.get("anchor", anchor)
		if not _is_number_pair(layer_anchor):
			errors.append("Layer %s must define a two-number anchor" % expected_id)
			return
		var layer_size: Variant = layer_data.get("size", canvas)
		if not _is_positive_integer_pair(layer_size):
			errors.append("Layer %s must define a positive integer size" % expected_id)
			return
		if Vector2i(int(layer_size[0]), int(layer_size[1])) != canvas_size:
			errors.append("Layer %s size must match canvas_size" % expected_id)
			return
		if not FileAccess.file_exists(directory.path_join(file)):
			errors.append("Layer %s file does not exist: %s" % [expected_id, file])
			return
		layers.append({
			"id": StringName(expected_id),
			"file": file,
			"z_index": int(layer_data.z_index),
			"anchor": Vector2(float(layer_anchor[0]), float(layer_anchor[1])),
			"size": Vector2i(int(layer_size[0]), int(layer_size[1])),
		})


func _is_positive_integer_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _is_whole_number(value[0]) and _is_whole_number(value[1]) and int(value[0]) > 0 and int(value[1]) > 0


func _is_number_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (typeof(value[0]) == TYPE_INT or typeof(value[0]) == TYPE_FLOAT) and (typeof(value[1]) == TYPE_INT or typeof(value[1]) == TYPE_FLOAT)


func _is_whole_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_equal_approx(float(value), round(float(value)))
