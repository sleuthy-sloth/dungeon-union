extends RefCounted

const FixedTickEventCommandScript = preload("res://src/events/fixed_tick_event_command.gd")

static func run(t: TestCase) -> void:
	_boot_rejects_invalid_catalog_before_exposing_indexes(t)
	_boot_exposes_indexes_after_validating_catalog(t)
	_production_boot_creates_and_drives_the_authored_event_runtime(t)
	_run_mode_transition_smoke_test(t)


static func _boot_rejects_invalid_catalog_before_exposing_indexes(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var first_worker := WorkerDefinition.new()
	first_worker.id = &"nib"
	catalog.worker_items.append(first_worker)
	var duplicate_worker := WorkerDefinition.new()
	duplicate_worker.id = &"nib"
	catalog.worker_items.append(duplicate_worker)
	catalog.rebuild_indexes()
	var root := AppRoot.new()
	root.content_catalog = catalog

	root.boot()

	t.equal(root.current_mode, &"content_error", "invalid catalog fails boot")
	t.check(root.boot_errors.has("duplicate worker id: nib"), "boot reports the invalid content")
	t.equal(root.active_catalog, null, "invalid catalog is not exposed to runtime")
	t.equal(catalog.workers.size(), 0, "invalid catalog indexes are cleared before validation")
	root.free()


static func _boot_exposes_indexes_after_validating_catalog(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	catalog.worker_items.append(worker)
	var root := AppRoot.new()
	root.content_catalog = catalog

	root.boot()

	t.equal(root.active_catalog, catalog, "valid catalog becomes the active runtime catalog")
	t.equal(root.active_catalog.workers.get(&"nib"), worker, "valid catalog indexes are exposed after boot")
	root.free()


static func _run_mode_transition_smoke_test(t: TestCase) -> void:
	var root := AppRoot.new()
	t.equal(root.current_mode, &"boot", "app starts in boot mode")
	root.change_mode(&"workplace")
	t.equal(root.current_mode, &"workplace", "mode transition is stored")
	root.free()


static func _production_boot_creates_and_drives_the_authored_event_runtime(t: TestCase) -> void:
	var root := AppRoot.new()
	root.content_catalog = load("res://content/bone_and_pick/catalog.tres")
	root.boot()
	t.check(root.event_runtime != null, "production boot creates the workplace event runtime")

	var snapshot := WorkplaceSimulation.create_fixture(42).snapshot()
	snapshot["active_issues"] = [
		&"cave_in_prevention", &"lantern_fume_exposure", &"maintenance_pay",
	]
	var started: EventDefinition = root.apply_fixed_tick(FixedTickEventCommandScript.new(0, 1, snapshot))
	t.check(started != null, "a supplied fixed-tick command selects and starts authored content")
	t.equal(started.id, &"cave_in_risk", "runtime uses the active workplace event catalog and worker role tags")
	t.equal(root.apply_fixed_tick(FixedTickEventCommandScript.new(180, 1, snapshot)), null, "started major event blocks the next fixed-tick command")
	t.check(root.complete_event(started.id), "AppRoot routes matching event completion to the runtime")
	root.free()
