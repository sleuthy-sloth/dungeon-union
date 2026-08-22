extends RefCounted

const CATALOG_PATH := "res://content/bone_and_pick/catalog.tres"


static func run(t: TestCase) -> void:
	_validator_rejects_invalid_event_roles_and_references(t)
	_production_content_meets_the_exact_slice_budget(t)


static func _production_content_meets_the_exact_slice_budget(t: TestCase) -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH)
	t.check(catalog != null, "Bone and Pick production catalog exists")
	if catalog == null:
		return

	t.equal(catalog.workplace_items.size(), 1, "Bone and Pick has exactly one workplace")
	var workplace: WorkplaceDefinition = catalog.workplace_items[0]
	var expected_workers: Array[StringName] = [
		&"brakka", &"clatter", &"drusk", &"ember", &"fizz", &"grib",
		&"hush", &"ivor", &"jink", &"kora", &"lute", &"nib",
	]
	var expected_disputes: Array[StringName] = [
		&"cave_in_prevention", &"lantern_fume_exposure", &"maintenance_pay",
	]
	var expected_events: Array[StringName] = [
		&"adventurer_alarm", &"cave_in_risk", &"foreman_intimidation",
		&"lantern_fumes", &"spontaneous_mutual_aid", &"unpaid_maintenance",
	]
	var expected_families := expected_events.duplicate()
	var catalog_worker_ids: Array[StringName] = []
	for worker in catalog.worker_items:
		catalog_worker_ids.append(worker.id)
	var catalog_event_ids: Array[StringName] = []
	var family_ids: Array[StringName] = []
	for event in catalog.event_items:
		catalog_event_ids.append(event.id)
		family_ids.append(event.family)

	t.equal(_sorted_unique(catalog_worker_ids), expected_workers, "catalog has the exact twelve stable worker IDs")
	t.equal(catalog_worker_ids.size(), expected_workers.size(), "catalog worker IDs are unique")
	t.equal(_sorted_unique(workplace.worker_ids), expected_workers, "workplace has the exact twelve stable worker IDs")
	t.equal(workplace.worker_ids.size(), expected_workers.size(), "workplace worker IDs are unique")
	t.equal(_sorted_unique(workplace.worker_ids), _sorted_unique(catalog_worker_ids), "catalog and workplace worker membership match")
	t.equal(_sorted_unique(workplace.dispute_ids), expected_disputes, "workplace has the exact three dispute IDs")
	t.equal(workplace.dispute_ids.size(), expected_disputes.size(), "workplace dispute IDs are unique")
	t.equal(_sorted_unique(catalog_event_ids), expected_events, "catalog has the exact six stable event IDs")
	t.equal(catalog_event_ids.size(), expected_events.size(), "catalog event IDs are unique")
	t.equal(_sorted_unique(workplace.event_ids), expected_events, "workplace has the exact six stable event IDs")
	t.equal(workplace.event_ids.size(), expected_events.size(), "workplace event IDs are unique")
	t.equal(_sorted_unique(workplace.event_ids), _sorted_unique(catalog_event_ids), "catalog and workplace event membership match")
	t.equal(_sorted_unique(family_ids), expected_families, "catalog has the exact six stable family IDs")
	t.equal(family_ids.size(), expected_families.size(), "event family IDs are unique")
	t.equal(ContentValidator.validate(catalog), [], "Bone and Pick roles and references pass startup validation")


static func _validator_rejects_invalid_event_roles_and_references(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.traits = [&"cautious"]
	worker.event_role_tags = [&"miner"]
	catalog.worker_items.append(worker)
	var event := EventDefinition.new()
	event.id = &"bad_alarm"
	event.family = &"adventurer_alarm"
	event.issue = &"missing_dispute"
	event.required_worker_tags = [&"missing_role"]
	catalog.event_items.append(event)
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"
	workplace.worker_ids = [&"nib"]
	workplace.dispute_ids = [&"safe_conditions"]
	workplace.event_ids = [&"bad_alarm", &"missing_event"]
	catalog.workplace_items.append(workplace)

	var errors := ContentValidator.validate(catalog)
	t.check(errors.has("workplace bone_and_pick references missing event id: missing_event"), "dangling workplace event references are rejected")
	t.check(errors.has("event bad_alarm references missing dispute id in workplace bone_and_pick: missing_dispute"), "dangling event dispute references are rejected")
	t.check(errors.has("event bad_alarm requires unavailable worker role in workplace bone_and_pick: missing_role"), "incompatible event roles are rejected")


static func _sorted_unique(ids: Array[StringName]) -> Array[StringName]:
	var unique: Dictionary[StringName, bool] = {}
	for id in ids:
		unique[id] = true
	var sorted_ids: Array[StringName] = unique.keys()
	sorted_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return sorted_ids
