class_name SaveMigrator
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1


func migrate(state: Dictionary) -> Dictionary:
	var raw_version: Variant = state.get("schema_version", 0)
	if typeof(raw_version) != TYPE_INT:
		return {}
	var source_version := int(raw_version)
	if source_version < 0 or source_version > CURRENT_SCHEMA_VERSION:
		return {}
	var migrated := state.duplicate(true)
	if source_version == 0:
		migrated["schema_version"] = CURRENT_SCHEMA_VERSION
	return migrated
