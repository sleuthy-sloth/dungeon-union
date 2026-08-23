extends RefCounted

const CATALOG_PATH := "res://content/bone_and_pick/catalog.tres"


static func run(t: TestCase) -> void:
	_validator_rejects_invalid_event_roles_and_references(t)
	_validator_rejects_invalid_event_outcomes(t)
	_validator_rejects_invalid_evidence_windows(t)
	_grievance_events_author_real_evidence_kinds(t)
	_production_content_meets_the_exact_slice_budget(t)


static func _production_content_meets_the_exact_slice_budget(t: TestCase) -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH)
	t.check(catalog != null, "Bone and Pick production catalog exists")
	if catalog == null:
		return
	var property_names: Array[StringName] = []
	for property in EventDefinition.new().get_property_list():
		property_names.append(StringName(property.name))
	if not property_names.has(&"event_kind"):
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
	var event_kinds: Dictionary[StringName, StringName] = {}
	for event in catalog.event_items:
		catalog_event_ids.append(event.id)
		family_ids.append(event.family)
		event_kinds[event.id] = event.event_kind

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
	t.equal(event_kinds.get(&"spontaneous_mutual_aid"), &"positive", "mutual aid is authored as a positive occurrence")
	for event_id in expected_events:
		if event_id != &"spontaneous_mutual_aid":
			t.equal(event_kinds.get(event_id), &"grievance", "%s is authored as a grievance occurrence" % event_id)
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


static func _validator_rejects_invalid_event_outcomes(t: TestCase) -> void:
	var property_names: Array[StringName] = []
	for property in EventDefinition.new().get_property_list():
		property_names.append(StringName(property.name))
	t.check(property_names.has(&"event_kind"), "event definitions expose an authored outcome classification")
	if not property_names.has(&"event_kind"):
		return
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.event_role_tags = [&"hauler"]
	catalog.worker_items.append(worker)
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"
	workplace.worker_ids = [&"nib"]
	workplace.dispute_ids = [&"safety"]
	catalog.workplace_items.append(workplace)
	var invalid := EventDefinition.new()
	invalid.id = &"invalid_outcome"
	invalid.family = &"invalid_outcome"
	invalid.event_kind = &"celebration"
	invalid.issue = &"safety"
	invalid.required_worker_tags = [&"hauler"]
	catalog.event_items.append(invalid)
	workplace.event_ids = [&"invalid_outcome"]

	var errors := ContentValidator.validate(catalog)
	t.check(errors.has("event invalid_outcome has invalid event kind: celebration"), "unknown event outcomes are rejected at startup")
	invalid.event_kind = &"positive"
	errors = ContentValidator.validate(catalog)
	t.check(errors.has("positive event invalid_outcome must not reference dispute: safety"), "positive events cannot be routed into dispute content")


static func _grievance_events_author_real_evidence_kinds(t: TestCase) -> void:
	var property_names: Array[StringName] = []
	for property in EventDefinition.new().get_property_list():
		property_names.append(StringName(property.name))
	for required in [&"evidence_kind", &"evidence_source", &"evidence_reliability", &"evidence_window_ticks"]:
		t.check(property_names.has(required), "grievance event content exposes authored %s" % required)
	if not property_names.has(&"evidence_kind"):
		return
	var catalog: ContentCatalog = load(CATALOG_PATH)
	for event in catalog.event_items:
		var authored_window := int(event.get("evidence_window_ticks")) if property_names.has(&"evidence_window_ticks") else 0
		if event.event_kind == EventDefinition.GRIEVANCE_KIND:
			t.check(not event.evidence_kind.is_empty(), "%s authors a real bargaining evidence kind" % event.id)
			t.check(not event.evidence_source.is_empty(), "%s authors a real evidence source" % event.id)
			t.check(event.evidence_reliability > 0, "%s authors positive evidence reliability" % event.id)
			t.check(authored_window > 3 * WorkplaceController.TICKS_PER_WORKDAY, "%s authors an evidence lifetime longer than the three-day fixture interval" % event.id)
		else:
			t.equal(event.evidence_kind, &"", "%s does not manufacture grievance evidence" % event.id)
			t.equal(authored_window, 0, "%s does not manufacture a grievance evidence lifetime" % event.id)


static func _validator_rejects_invalid_evidence_windows(t: TestCase) -> void:
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.event_role_tags = [&"hauler"]
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"
	workplace.worker_ids = [&"nib"]
	workplace.dispute_ids = [&"safety"]
	workplace.event_ids = [&"window_probe"]
	var event := EventDefinition.new()
	event.id = &"window_probe"
	event.family = &"window_probe"
	event.issue = &"safety"
	event.event_kind = EventDefinition.GRIEVANCE_KIND
	event.required_worker_tags = [&"hauler"]
	event.presentation_title = "Window probe"
	event.presentation_description = "A complete validation fixture."
	event.visual_pattern = "///"
	event.evidence_kind = &"testimony"
	event.evidence_source = &"nib"
	event.evidence_reliability = 2
	event.evidence_window_ticks = 0
	var catalog := ContentCatalog.new()
	catalog.worker_items = [worker]
	catalog.workplace_items = [workplace]
	catalog.event_items = [event]
	t.check(ContentValidator.validate(catalog).has("grievance event window_probe has non-positive evidence window"), "startup validation rejects a missing authored grievance evidence lifetime")
	event.event_kind = EventDefinition.POSITIVE_KIND
	event.issue = &""
	event.evidence_kind = &""
	event.evidence_source = &""
	event.evidence_reliability = 0
	event.evidence_window_ticks = 1
	t.check(ContentValidator.validate(catalog).has("positive event window_probe must not author grievance evidence"), "startup validation rejects a positive-event evidence lifetime")


static func _sorted_unique(ids: Array[StringName]) -> Array[StringName]:
	var unique: Dictionary[StringName, bool] = {}
	for id in ids:
		unique[id] = true
	var sorted_ids: Array[StringName] = unique.keys()
	sorted_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return sorted_ids
