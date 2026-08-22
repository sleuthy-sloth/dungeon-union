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

	t.equal(catalog.worker_items.size(), 12, "Bone and Pick has exactly twelve workers")
	t.equal(catalog.workplace_items.size(), 1, "Bone and Pick has exactly one workplace")
	var workplace: WorkplaceDefinition = catalog.workplace_items[0]
	t.equal(workplace.dispute_ids.size(), 3, "Bone and Pick has exactly three dispute IDs")
	t.equal(catalog.event_items.size(), 6, "Bone and Pick has exactly six authored events")

	var families: Dictionary[StringName, bool] = {}
	for event in catalog.event_items:
		families[event.family] = true
	t.equal(families.size(), 6, "Bone and Pick has six distinct event-family tags")
	t.equal(ContentValidator.validate(catalog), [], "Bone and Pick roles and references pass startup validation")


static func _validator_rejects_invalid_event_roles_and_references(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.traits = [&"miner"]
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
