extends RefCounted

const SaveServiceScript = preload("res://src/save/save_service.gd")
const SaveMigratorScript = preload("res://src/save/save_migrator.gd")

const SAVE_PATH := "res://work/task7_campaign.save"


static func run(t: TestCase) -> void:
	_durable_state_round_trips_without_transient_changes(t)
	_old_state_migrates_to_the_current_schema(t)
	_rotating_autosaves_keep_the_three_newest_states(t)
	_autosaving_preserves_a_corrupt_target_slot(t)
	_corrupt_primary_and_newest_autosave_recover_from_the_next_valid_copy(t)
	_migration_failure_preserves_the_original_and_recovers(t)
	_cleanup()


static func _durable_state_round_trips_without_transient_changes(t: TestCase) -> void:
	var state := {
		"schema_version": 1,
		"build_id": "slice-1",
		"seed": 42,
		"chapter": &"bone_and_pick",
		"day": 3,
		"treasury": 9,
		"resources": {"solidarity": 64, "public_support": 38},
		"workers": {"nib": {"trust": 67, "memory_flags": [&"reported_fumes"]}},
		"grievances": [{"id": &"gas_01", "phase": &"documented"}],
		"contracts": {"safety": &"ventilation_and_refusal"},
		"employer_posture": &"reluctant",
		"upgrades": [&"legal_desk_1"],
		"challenge_unlocks": [],
		"settings_refs": {"accessibility": &"default"},
	}

	t.equal(SaveServiceScript.round_trip_for_test(state), state, "save preserves representative durable state")

	_cleanup()
	var service: Variant = SaveServiceScript.new()
	t.equal(service.save_campaign(SAVE_PATH, state), OK, "campaign save succeeds")
	t.equal(service.load_campaign(SAVE_PATH), state, "disk save restores the same durable state")
	t.check(not FileAccess.file_exists(SAVE_PATH + ".tmp"), "successful replacement leaves no temporary save")
	var first_envelope: Dictionary = _read_stored_dictionary(SAVE_PATH)
	t.check(int(first_envelope.get("last_successful_save_timestamp", 0)) > 0, "save stores a successful-save timestamp")
	t.equal(service.save_campaign(SAVE_PATH, state.merged({"day": 4}, true)), OK, "an existing save is atomically replaced")
	t.equal(service.load_campaign(SAVE_PATH).day, 4, "atomic replacement publishes the new durable state")


static func _old_state_migrates_to_the_current_schema(t: TestCase) -> void:
	var old_state := {"schema_version": 0, "seed": 7, "treasury": 4}
	var migrated: Dictionary = SaveMigratorScript.new().migrate(old_state)

	t.equal(migrated, {"schema_version": 1, "seed": 7, "treasury": 4}, "schema zero migrates without losing durable fields")
	t.equal(old_state.schema_version, 0, "migration does not mutate the source state")
	t.equal(SaveMigratorScript.new().migrate({"schema_version": 99, "seed": 7}), {}, "unknown future schemas fail safely")
	t.equal(SaveMigratorScript.new().migrate({"schema_version": "one", "seed": 7}), {}, "malformed schema versions fail safely")


static func _rotating_autosaves_keep_the_three_newest_states(t: TestCase) -> void:
	_cleanup()
	var service: Variant = SaveServiceScript.new()
	var paths: Array[String] = service.autosave_paths(SAVE_PATH)
	t.equal(paths, [SAVE_PATH + ".autosave_0", SAVE_PATH + ".autosave_1", SAVE_PATH + ".autosave_2"], "autosave exposes exactly three stable rotating paths")

	for day in [1, 2, 3, 4]:
		t.equal(service.save_autosave(SAVE_PATH, {"schema_version": 1, "seed": 42, "day": day}), OK, "autosave rotation writes day %d" % day)

	t.equal(service.load_campaign(paths[0]).day, 4, "the fourth autosave replaces only its ring slot")
	t.equal(service.load_campaign(paths[1]).day, 2, "the second ring slot remains independently valid")
	t.equal(service.load_campaign(paths[2]).day, 3, "the third ring slot remains independently valid")
	_overwrite_with_corruption(SAVE_PATH)
	t.equal(service.load_campaign(SAVE_PATH).day, 4, "recovery selects the highest protected generation rather than the first path")


static func _autosaving_preserves_a_corrupt_target_slot(t: TestCase) -> void:
	_cleanup()
	var service: Variant = SaveServiceScript.new()
	for day in [1, 2, 3]:
		t.equal(service.save_autosave(SAVE_PATH, {"schema_version": 1, "seed": 42, "day": day}), OK, "target-preservation fixture writes day %d" % day)
	var target_path: String = service.autosave_paths(SAVE_PATH)[0]
	_overwrite_with_corruption(target_path)
	var corrupt_bytes := FileAccess.get_file_as_bytes(target_path)

	t.equal(service.save_autosave(SAVE_PATH, {"schema_version": 1, "seed": 42, "day": 4}), OK, "autosave replaces the next ring target")
	t.equal(FileAccess.get_file_as_bytes(target_path + ".corrupt"), corrupt_bytes, "autosaving preserves a corrupt target before replacement")
	t.equal(service.load_campaign(target_path).day, 4, "the preserved target is atomically replaced by the new autosave")


static func _corrupt_primary_and_newest_autosave_recover_from_the_next_valid_copy(t: TestCase) -> void:
	_cleanup()
	var service: Variant = SaveServiceScript.new()
	var primary := {"schema_version": 1, "seed": 42, "day": 9}
	var older := {"schema_version": 1, "seed": 42, "day": 6}
	var newest := {"schema_version": 1, "seed": 42, "day": 7}
	t.equal(service.save_campaign(SAVE_PATH, primary), OK, "primary save exists before corruption")
	t.equal(service.save_autosave(SAVE_PATH, older), OK, "older recovery autosave exists")
	t.equal(service.save_autosave(SAVE_PATH, newest), OK, "newest recovery autosave exists")
	_overwrite_with_corruption(SAVE_PATH)
	_overwrite_with_corruption(service.autosave_paths(SAVE_PATH)[1])

	var recovered: Dictionary = service.load_campaign(SAVE_PATH)
	t.equal(recovered, older, "checksum failures fall back to the newest valid rotating autosave")
	t.check(FileAccess.file_exists(SAVE_PATH + ".corrupt"), "the corrupt primary is preserved before recovery")
	t.check(FileAccess.file_exists(SAVE_PATH + ".autosave_1.corrupt"), "a corrupt autosave is preserved before trying the next copy")


static func _migration_failure_preserves_the_original_and_recovers(t: TestCase) -> void:
	_cleanup()
	var service: Variant = SaveServiceScript.new()
	var recovery := {"schema_version": 1, "seed": 42, "day": 5}
	t.equal(service.save_autosave(SAVE_PATH, recovery), OK, "migration recovery autosave exists")
	t.equal(service.save_campaign(SAVE_PATH, {"schema_version": 1, "seed": 42, "day": 8}), OK, "future-schema fixture starts as a valid save")
	_rewrite_with_future_schema(SAVE_PATH)
	var original_bytes := FileAccess.get_file_as_bytes(SAVE_PATH)

	t.equal(service.load_campaign(SAVE_PATH), recovery, "unsupported schema recovers the newest valid autosave")
	t.equal(FileAccess.get_file_as_bytes(SAVE_PATH + ".corrupt"), original_bytes, "migration failure preserves the original save bytes")


static func _overwrite_with_corruption(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"payload": {"schema_version": 1, "seed": 999}, "checksum": "not-the-checksum"})
	file.close()


static func _rewrite_with_future_schema(path: String) -> void:
	var envelope := _read_stored_dictionary(path)
	var payload: Dictionary = envelope.payload
	payload["schema_version"] = 99
	envelope["payload"] = payload
	envelope["checksum"] = _checksum_envelope(envelope)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(envelope)
	file.close()


static func _read_stored_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var stored: Dictionary = file.get_var(false)
	file.close()
	return stored


static func _checksum_envelope(envelope: Dictionary) -> String:
	var protected_data := {
		"payload": envelope.payload,
		"generation": int(envelope.get("generation", 0)),
		"last_successful_save_timestamp": int(envelope.get("last_successful_save_timestamp", 0)),
	}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(protected_data))
	return context.finish().hex_encode()


static func _cleanup() -> void:
	var paths: Array[String] = [
		SAVE_PATH,
		SAVE_PATH + ".tmp",
		SAVE_PATH + ".corrupt",
		SAVE_PATH + ".autosave_0",
		SAVE_PATH + ".autosave_0.tmp",
		SAVE_PATH + ".autosave_0.corrupt",
		SAVE_PATH + ".autosave_1",
		SAVE_PATH + ".autosave_1.tmp",
		SAVE_PATH + ".autosave_1.corrupt",
		SAVE_PATH + ".autosave_2",
		SAVE_PATH + ".autosave_2.tmp",
		SAVE_PATH + ".autosave_2.corrupt",
	]
	for path in paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
