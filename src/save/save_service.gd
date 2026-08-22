class_name SaveService
extends RefCounted

const SaveMigratorScript = preload("res://src/save/save_migrator.gd")

const SCHEMA_VERSION := SaveMigratorScript.CURRENT_SCHEMA_VERSION
const AUTOSAVE_COUNT := 3

var _migrator := SaveMigratorScript.new()


func save_campaign(path: String, state: Dictionary) -> Error:
	var payload := state.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	return _write_campaign(path, payload, 0, int(Time.get_unix_time_from_system()))


func _write_campaign(path: String, payload: Dictionary, generation: int, timestamp: int) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temp_path := absolute_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(_envelope_for(payload, generation, timestamp))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return write_error
	var replace_error := DirAccess.rename_absolute(temp_path, absolute_path)
	if replace_error != OK:
		DirAccess.remove_absolute(temp_path)
	return replace_error


func load_campaign(path: String) -> Dictionary:
	var direct := _read_state(path)
	if direct.ok:
		return direct.state
	if FileAccess.file_exists(path):
		_preserve_corrupt(path)
	if path.contains(".autosave_"):
		return {}
	var newest: Dictionary = {}
	for autosave_path in autosave_paths(path):
		var recovered := _read_state(autosave_path)
		if recovered.ok:
			if newest.is_empty() or _is_newer(recovered, newest):
				newest = recovered
		elif FileAccess.file_exists(autosave_path):
			_preserve_corrupt(autosave_path)
	return newest.state if not newest.is_empty() else {}


func autosave_paths(path: String) -> Array[String]:
	var paths: Array[String] = []
	for index in AUTOSAVE_COUNT:
		paths.append("%s.autosave_%d" % [path, index])
	return paths


func save_autosave(path: String, state: Dictionary) -> Error:
	var paths := autosave_paths(path)
	var latest_generation := 0
	for autosave_path in paths:
		var existing := _read_state(autosave_path)
		if existing.ok:
			latest_generation = maxi(latest_generation, int(existing.generation))
		elif FileAccess.file_exists(autosave_path):
			_preserve_corrupt(autosave_path)
	var next_generation := latest_generation + 1
	var target_index := (next_generation - 1) % AUTOSAVE_COUNT
	var payload := state.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	return _write_campaign(
		paths[target_index],
		payload,
		next_generation,
		int(Time.get_unix_time_from_system())
	)


static func round_trip_for_test(state: Dictionary) -> Dictionary:
	var service: Variant = load("res://src/save/save_service.gd").new()
	var payload := state.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	var bytes := var_to_bytes(service._envelope_for(payload, 0, 0))
	var decoded: Variant = bytes_to_var(bytes)
	var result: Dictionary = service._state_from_value(decoded)
	return result.state if result.ok else {}


func _envelope_for(payload: Dictionary, generation: int, timestamp: int) -> Dictionary:
	return {
		"payload": payload.duplicate(true),
		"generation": generation,
		"last_successful_save_timestamp": timestamp,
		"checksum": _checksum(_protected_data(payload, generation, timestamp)),
	}


func _read_state(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
	var stored: Variant = file.get_var(false)
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
	return _state_from_value(stored)


func _state_from_value(stored: Variant) -> Dictionary:
	if not stored is Dictionary:
		return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
	var serialized: Dictionary = stored
	var payload: Dictionary
	var generation := 0
	var timestamp := 0
	if serialized.has("payload") or serialized.has("checksum"):
		if not serialized.get("payload") is Dictionary:
			return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
		payload = serialized.payload
		var raw_generation: Variant = serialized.get("generation", 0)
		var raw_timestamp: Variant = serialized.get("last_successful_save_timestamp", 0)
		if typeof(raw_generation) != TYPE_INT or typeof(raw_timestamp) != TYPE_INT:
			return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
		generation = int(raw_generation)
		timestamp = int(raw_timestamp)
		if generation < 0 or timestamp < 0:
			return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
		if String(serialized.get("checksum", "")) != _checksum(_protected_data(payload, generation, timestamp)):
			return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
	else:
		if serialized.get("schema_version", 0) != 0:
			return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
		payload = serialized
	var migrated := _migrator.migrate(payload)
	if migrated.is_empty():
		return {"ok": false, "state": {}, "generation": 0, "timestamp": 0}
	return {"ok": true, "state": migrated, "generation": generation, "timestamp": timestamp}


func _protected_data(payload: Dictionary, generation: int, timestamp: int) -> Dictionary:
	return {
		"payload": payload,
		"generation": generation,
		"last_successful_save_timestamp": timestamp,
	}


func _checksum(data: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(data))
	return context.finish().hex_encode()


func _is_newer(candidate: Dictionary, current: Dictionary) -> bool:
	if int(candidate.generation) != int(current.generation):
		return int(candidate.generation) > int(current.generation)
	return int(candidate.timestamp) > int(current.timestamp)


func _preserve_corrupt(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var preserved_path := absolute_path + ".corrupt"
	var suffix := 1
	while FileAccess.file_exists(preserved_path):
		preserved_path = "%s.corrupt.%d" % [absolute_path, suffix]
		suffix += 1
	DirAccess.rename_absolute(absolute_path, preserved_path)
