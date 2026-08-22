extends RefCounted


static func run(t: TestCase) -> void:
	_records_preserve_their_constructor_values(t)
	_reporting_and_evidence_follow_the_lifecycle(t)
	_retrieved_state_cannot_mutate_service_state(t)
	_terminal_grievances_ignore_new_evidence(t)
	_invalid_grievance_ids_are_safe_no_ops(t)
	_deadlines_expire_only_after_their_logical_tick(t)
	_late_evidence_expires_the_grievance_on_insertion(t)


static func _records_preserve_their_constructor_values(t: TestCase) -> void:
	var affected_workers: Array[StringName] = [&"nib"]
	var incident := IncidentRecord.new(&"gas_01", &"unsafe_fumes", affected_workers, 10)
	affected_workers.append(&"brakka")
	var exposed_workers := incident.affected_workers
	exposed_workers.append(&"clatter")

	t.equal(incident.id, &"gas_01", "incident keeps its stable id")
	t.equal(incident.issue, &"unsafe_fumes", "incident keeps its issue")
	t.equal(incident.affected_workers, [&"nib"], "incident workers are isolated from caller mutation")
	t.equal(incident.tick, 10, "incident keeps its logical tick")

	var evidence := EvidenceRecord.new(&"testimony", 2, 30)
	t.equal(evidence.source, &"testimony", "evidence keeps its source")
	t.equal(evidence.reliability, 2, "evidence keeps its reliability")
	t.equal(evidence.deadline_tick, 30, "evidence keeps its deadline tick")


static func _reporting_and_evidence_follow_the_lifecycle(t: TestCase) -> void:
	var service := GrievanceService.new()
	var id := service.report(IncidentRecord.new(&"gas_01", &"unsafe_fumes", [&"nib"], 10))

	t.equal(id, &"gas_01", "grievance id is derived from the incident id")
	t.equal(service.get_state(id).phase, &"reported", "new grievance is reported")
	service.add_evidence(id, EvidenceRecord.new(&"testimony", 1, 30))
	t.equal(service.get_state(id).phase, &"investigating", "partial evidence starts investigation")
	service.add_evidence(id, EvidenceRecord.new(&"inspection", 1, 30))
	t.equal(service.get_state(id).phase, &"documented", "sufficient evidence documents case")
	t.equal(service.get_state(id).evidence_score, 2, "evidence reliability accumulates")


static func _retrieved_state_cannot_mutate_service_state(t: TestCase) -> void:
	var service := GrievanceService.new()
	var id := service.report(IncidentRecord.new(&"gas_04", &"unsafe_fumes", [&"nib"], 10))
	var view := service.get_state(id)
	view.phase = &"documented"
	view.evidence_score = 99
	view.deadline_tick = 99
	view.affected_workers.append(&"brakka")
	var state := service.get_state(id)

	t.equal(state.phase, &"reported", "retrieved phase mutation cannot bypass the service")
	t.equal(state.evidence_score, 0, "retrieved score mutation cannot bypass the service")
	t.equal(state.deadline_tick, 0, "retrieved deadline mutation cannot bypass the service")
	t.equal(state.affected_workers, [&"nib"], "retrieved worker mutation cannot bypass the service")


static func _terminal_grievances_ignore_new_evidence(t: TestCase) -> void:
	var service := GrievanceService.new()
	var id := service.report(IncidentRecord.new(&"gas_02", &"unsafe_fumes", [&"nib"], 10))
	service.add_evidence(id, EvidenceRecord.new(&"testimony", 2, 30))
	service.advance_deadlines(31)

	service.add_evidence(id, EvidenceRecord.new(&"inspection", 5, 40))
	var expired := service.get_state(id)
	t.equal(expired.phase, &"expired", "adding evidence to an expired grievance has no effect")
	t.equal(expired.evidence_score, 2, "expired grievance retains its evidence score")
	t.equal(expired.deadline_tick, 30, "expired grievance retains its deadline")


static func _invalid_grievance_ids_are_safe_no_ops(t: TestCase) -> void:
	var service := GrievanceService.new()
	service.add_evidence(&"missing", EvidenceRecord.new(&"testimony", 2, 30))

	t.equal(service.get_state(&"missing"), null, "unknown grievance state is absent")


static func _deadlines_expire_only_after_their_logical_tick(t: TestCase) -> void:
	var service := GrievanceService.new()
	var id := service.report(IncidentRecord.new(&"gas_03", &"unsafe_fumes", [&"nib"], 10))
	service.add_evidence(id, EvidenceRecord.new(&"testimony", 2, 30))

	service.advance_deadlines(30)
	t.equal(service.get_state(id).phase, &"documented", "deadline tick itself remains valid")
	service.advance_deadlines(31)
	t.equal(service.get_state(id).phase, &"expired", "deadline expiry is deterministic")


static func _late_evidence_expires_the_grievance_on_insertion(t: TestCase) -> void:
	var service := GrievanceService.new()
	service.advance_deadlines(31)
	var id := service.report(IncidentRecord.new(&"gas_05", &"unsafe_fumes", [&"nib"], 10))

	service.add_evidence(id, EvidenceRecord.new(&"testimony", 2, 30))
	var state := service.get_state(id)
	t.equal(state.phase, &"expired", "late evidence expires the grievance instead of documenting it")
	t.equal(state.evidence_score, 0, "late evidence does not contribute a usable score")
	t.equal(state.deadline_tick, 30, "late evidence preserves the expired deadline")
