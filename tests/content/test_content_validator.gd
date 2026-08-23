extends RefCounted

static func run(t: TestCase) -> void:
	_validate_rejects_empty_and_duplicate_worker_ids(t)
	_validate_rejects_dangling_worker_job_references(t)
	_validate_rejects_dangling_workplace_references(t)
	_rebuild_indexes_exposes_defined_content_by_id(t)
	_validate_accepts_twelve_unique_workers_with_existing_job_references(t)


static func _validate_rejects_empty_and_duplicate_worker_ids(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var empty_worker := WorkerDefinition.new()
	empty_worker.id = &""
	empty_worker.display_name = "Nib"
	catalog.worker_items.append(empty_worker)
	var duplicate_worker := WorkerDefinition.new()
	duplicate_worker.id = &"burrower"
	catalog.worker_items.append(duplicate_worker)
	var second_duplicate_worker := WorkerDefinition.new()
	second_duplicate_worker.id = &"burrower"
	catalog.worker_items.append(second_duplicate_worker)

	var errors := ContentValidator.validate(catalog)

	t.check(errors.has("worker has empty id"), "empty worker id is rejected")
	t.check(errors.has("duplicate worker id: burrower"), "duplicate worker id is rejected")


static func _validate_rejects_dangling_worker_job_references(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	worker.job_id = &"missing_job"
	catalog.worker_items.append(worker)

	var errors := ContentValidator.validate(catalog)

	t.check(
		errors.has("worker nib references missing job id: missing_job"),
		"dangling worker job reference is rejected"
	)


static func _validate_rejects_dangling_workplace_references(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"
	workplace.worker_ids = [&"missing_worker"]
	workplace.job_ids = [&"missing_job"]
	catalog.workplace_items.append(workplace)

	var errors := ContentValidator.validate(catalog)

	t.check(
		errors.has("workplace bone_and_pick references missing worker id: missing_worker"),
		"dangling workplace worker reference is rejected"
	)
	t.check(
		errors.has("workplace bone_and_pick references missing job id: missing_job"),
		"dangling workplace job reference is rejected"
	)


static func _rebuild_indexes_exposes_defined_content_by_id(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var worker := WorkerDefinition.new()
	worker.id = &"nib"
	catalog.worker_items.append(worker)
	var job := JobDefinition.new()
	job.id = &"miner"
	catalog.job_items.append(job)
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"
	catalog.workplace_items.append(workplace)

	catalog.rebuild_indexes()

	t.equal(catalog.workers.get(&"nib"), worker, "worker index uses the stable id")
	t.equal(catalog.jobs.get(&"miner"), job, "job index uses the stable id")
	t.equal(catalog.workplaces.get(&"bone_and_pick"), workplace, "workplace index uses the stable id")


static func _validate_accepts_twelve_unique_workers_with_existing_job_references(t: TestCase) -> void:
	var catalog := ContentCatalog.new()
	var job := JobDefinition.new()
	job.id = &"miner"
	job.display_name = "Miner"
	catalog.job_items.append(job)
	var workplace := WorkplaceDefinition.new()
	workplace.id = &"bone_and_pick"

	for worker_number in 12:
		var worker := WorkerDefinition.new()
		worker.id = StringName("worker_%d" % worker_number)
		worker.display_name = "Worker %d" % worker_number
		worker.job_id = &"miner"
		catalog.worker_items.append(worker)
		workplace.worker_ids.append(worker.id)
	workplace.job_ids.append(job.id)
	catalog.workplace_items.append(workplace)

	var errors := ContentValidator.validate(catalog)

	t.equal(errors, [], "twelve valid workers and existing jobs have no validation errors")
