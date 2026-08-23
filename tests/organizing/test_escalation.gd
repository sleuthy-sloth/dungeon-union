extends RefCounted

const OrganizingServiceScript = preload("res://src/organizing/organizing_service.gd")
const ActionProposalScript = preload("res://src/organizing/action_proposal.gd")
const UnionResourcesScript = preload("res://src/organizing/union_resources.gd")
const GrievanceStateScript = preload("res://src/grievances/grievance_state.gd")

static func run(t: TestCase) -> void:
	_forecast_names_workers_by_individual_consent(t)
	_executable_ranks_enforce_their_prerequisites(t)
	_locked_future_actions_remain_forecastable(t)
	_execution_applies_only_the_rank_resource_cost(t)
	_public_execution_is_transition_bound_and_idempotent(t)
	_zero_evidence_cannot_cross_the_ratification_boundary(t)
	_work_to_rule_preflights_every_negative_cost(t)
	_resources_clamp_to_their_supported_bounds(t)
	_service_copies_worker_and_grievance_inputs(t)
	_escalation_is_sequential_idempotent_and_resolves_only_by_remedy(t)


static func _forecast_names_workers_by_individual_consent(t: TestCase) -> void:
	var service: Variant = OrganizingServiceScript.fixture_with_workers([20, 65, 80])
	var strike := ActionProposalScript.new(&"strike", &"gas_case", 60)
	var forecast: Variant = service.forecast(strike)

	t.equal(forecast.ready_workers, [&"worker_2", &"worker_3"], "ready workers meet their own threshold")
	t.equal(forecast.uncertain_workers, [], "workers far below the threshold are unwilling")
	t.equal(forecast.unwilling_workers, [&"worker_1"], "forecast names workers who decline")
	t.equal(forecast.ready_count, 2, "two workers meet strike threshold")
	t.check(not forecast.can_execute, "strike requires documented case and vote")
	t.equal(forecast.blocker, "action is locked in this slice: strike", "locked actions explain the slice boundary")


static func _executable_ranks_enforce_their_prerequisites(t: TestCase) -> void:
	var service: Variant = OrganizingServiceScript.fixture_with_workers([75, 69, 20], UnionResourcesScript.new(50, 5, 50))
	var case_state := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	case_state.phase = &"documented"
	service.register_grievance(case_state)

	t.check(service.forecast(ActionProposalScript.new(&"informal", &"gas_case", 60)).can_execute, "informal action is the first available step")
	t.equal(service.forecast(ActionProposalScript.new(&"grievance", &"gas_case", 60)).blocker, "next escalation step is informal", "formal filing cannot skip informal outreach")
	t.check(service.execute(ActionProposalScript.new(&"informal", &"gas_case", 60)).executed, "informal step advances the authored sequence")
	t.check(service.forecast(ActionProposalScript.new(&"grievance", &"gas_case", 60)).can_execute, "documented grievance becomes executable after informal outreach")

	var missing_case: Variant = service.forecast(ActionProposalScript.new(&"grievance", &"missing", 60))
	t.check(not missing_case.can_execute, "grievance needs an existing case")
	t.equal(missing_case.blocker, "requires a grievance: missing", "missing case names the blocker")

	var thin_support: Variant = OrganizingServiceScript.fixture_with_workers([80, 25, 20])
	var submitted := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	submitted.phase = &"submitted"
	submitted.action_history = [&"informal", &"grievance"]
	thin_support.register_grievance(submitted)
	var petition: Variant = thin_support.forecast(ActionProposalScript.new(&"petition", &"gas_case", 60))
	t.check(not petition.can_execute, "petition fails without two ready workers")
	t.equal(petition.blocker, "requires at least 2 ready workers", "participation blocker states its minimum")
	var no_fund: Variant = OrganizingServiceScript.fixture_with_workers([80, 75, 20])
	var escalated := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	escalated.phase = &"escalated"
	escalated.action_history = [&"informal", &"grievance", &"petition"]
	no_fund.register_grievance(escalated)
	var work_to_rule: Variant = no_fund.forecast(ActionProposalScript.new(&"work_to_rule", &"gas_case", 60))
	t.check(not work_to_rule.can_execute, "work-to-rule cannot spend treasury below zero")
	t.equal(work_to_rule.blocker, "requires 5 treasury, has 0", "treasury blocker reports the needed and available amount")


static func _locked_future_actions_remain_forecastable(t: TestCase) -> void:
	var service: Variant = OrganizingServiceScript.fixture_with_workers([90, 90, 90])
	var documented := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	documented.phase = &"documented"
	service.register_grievance(documented)

	for action in [&"walkout", &"strike"]:
		var forecast: Variant = service.forecast(ActionProposalScript.new(action, &"gas_case", 60, true))
		t.equal(forecast.ready_count, 3, "%s keeps its named consent forecast" % action)
		t.check(not forecast.can_execute, "%s is not executable in the slice" % action)
		t.equal(forecast.blocker, "action is locked in this slice: %s" % action, "%s reports its lock" % action)


static func _execution_applies_only_the_rank_resource_cost(t: TestCase) -> void:
	var resources := UnionResourcesScript.new(50, 5, 50, 1)
	var service: Variant = OrganizingServiceScript.fixture_with_workers([90, 90, 20], resources)
	var documented := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	documented.phase = &"escalated"
	documented.action_history = [&"informal", &"grievance", &"petition"]
	service.register_grievance(documented)

	var result: Variant = service.execute(ActionProposalScript.new(&"work_to_rule", &"gas_case", 60))
	t.check(result.executed, "ready work-to-rule action executes")
	t.equal(result.action, &"work_to_rule", "execution returns the action taken")
	t.equal(result.ready_workers, [&"worker_1", &"worker_2"], "execution reports named consenting workers")
	t.equal(service.resources_snapshot(), {"solidarity": 45, "treasury": 0, "public_support": 48, "organizer_capacity": 1}, "work-to-rule applies its bounded resource cost")

	var locked: Variant = service.execute(ActionProposalScript.new(&"strike", &"gas_case", 60, true))
	t.check(not locked.executed, "locked future action cannot mutate resources")
	t.equal(locked.blocker, "action is locked in this slice: strike", "failed execution returns the forecast blocker")
	t.equal(service.resources_snapshot().treasury, 0, "failed execution leaves resources unchanged")


static func _public_execution_is_transition_bound_and_idempotent(t: TestCase) -> void:
	var actions: Array[StringName] = [&"informal", &"grievance", &"petition", &"work_to_rule"]
	var phases_before: Array[StringName] = [&"documented", &"documented", &"submitted", &"escalated"]
	var phases_after: Array[StringName] = [&"documented", &"submitted", &"escalated", &"escalated"]
	for action_index in actions.size():
		var action := actions[action_index]
		var workers: Array = []
		for worker_id in [&"nib", &"brakka", &"clatter"]:
			var worker := WorkerState.new(worker_id)
			worker.trust = 55
			worker.action_willingness = 90
			worker.bargaining_priorities = {&"safety": 3}
			workers.append(worker)
		var case_state := GrievanceStateScript.new(StringName("%s_case" % action), &"cave_in_prevention", [&"nib"])
		case_state.phase = phases_before[action_index]
		case_state.action_history = actions.slice(0, action_index)
		var service: Variant = OrganizingServiceScript.new(workers, [case_state], UnionResourcesScript.new(40, 5, 2, 1))
		t.check(service.has_method("grievance_view") and service.has_method("grievance_views"), "organizing publishes authoritative copied grievance views")
		if not service.has_method("grievance_view") or not service.has_method("grievance_views"):
			continue
		var proposal := ActionProposalScript.new(action, case_state.id, 50)
		var first: Dictionary = service.execute(proposal)
		t.check(first.executed, "%s public execution commits its grievance transition" % action)
		var progressed: Variant = service.grievance_view(case_state.id)
		t.equal(progressed.phase, phases_after[action_index], "%s publishes its authored non-terminal phase" % action)
		t.equal(progressed.action_history, actions.slice(0, action_index + 1), "%s records the committed ordered action" % action)
		t.equal(progressed.resolved_action, &"", "%s cannot manufacture a remedy" % action)
		var after_first: Dictionary = service.resources_snapshot()
		t.check(not service.register_grievance(case_state), "%s stale caller snapshot cannot reopen the authoritative grievance" % action)
		var repeated: Dictionary = service.execute(proposal)
		t.check(not repeated.executed, "%s second public execution is rejected" % action)
		t.equal(service.resources_snapshot(), after_first, "%s second public execution cannot change resources" % action)


static func _ratify_safety(state: NegotiationState) -> Dictionary:
	var resolver := NegotiationResolver.bone_and_pick(state)
	var safety_evidence := state.first_evidence_id_for_kinds([&"fume_testimony", &"shoring_testimony"])
	var tool_evidence := state.first_evidence_id_for_kinds([&"tool_ledger", &"tool_testimony"])
	var terms := {
		&"safety": resolver.press(&"safety", safety_evidence),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", tool_evidence),
	}
	var agreement: Dictionary = resolver.issue_tentative_agreement(terms) if resolver.has_method("issue_tentative_agreement") else terms
	return resolver.ratify(agreement)


static func _zero_evidence_cannot_cross_the_ratification_boundary(t: TestCase) -> void:
	var workers: Array = []
	for worker_id in [&"nib", &"brakka", &"clatter"]:
		var worker := WorkerState.new(worker_id)
		worker.trust = 60
		worker.action_willingness = 90
		worker.bargaining_priorities = {&"safety": 3}
		workers.append(worker)
	var reported := GrievanceStateScript.new(&"collapse_occurrence_1", &"cave_in_prevention", [&"nib"])
	var service: Variant = OrganizingServiceScript.new(
		workers,
		[reported],
		UnionResourcesScript.new(39, 15, 0, 1)
	)
	var composer: Variant = load("res://src/negotiation/bone_and_pick_negotiation_composer.gd").new()
	var before: NegotiationState = composer.compose(
		service.worker_views(), service.grievance_views(), service.resources_snapshot()
	)
	t.equal(before.evidence_strength(&"fume_testimony"), 0, "reported grievances do not manufacture evidence")
	t.check(not _ratify_safety(before).ratified, "zero evidence rejects before the leverage threshold")
	var before_offer := NegotiationResolver.bone_and_pick(before).press(&"safety", &"fume_testimony")

	var result: Dictionary = service.execute(ActionProposalScript.new(&"informal", reported.id, 50))
	t.check(result.executed, "the exact public informal action executes")
	var after: NegotiationState = composer.compose(
		service.worker_views(), service.grievance_views(), service.resources_snapshot()
	)
	t.equal(after.solidarity, 41, "informal action crosses the solidarity leverage threshold")
	t.equal(after.evidence_strength(&"fume_testimony"), 0, "informal action remains evidence-free")
	var blocked_vote := _ratify_safety(after)
	t.check(not blocked_vote.ratified, "earned evidence is required at the production ratification boundary")
	t.equal(blocked_vote.eligibility_blockers, [&"safety"], "the production boundary names the unsupported safety issue")

	var authoritative_grievances := GrievanceService.new()
	var documented_id := authoritative_grievances.report(IncidentRecord.new(
		&"collapse_occurrence_2", &"cave_in_prevention", [&"nib"], 12
	))
	authoritative_grievances.add_evidence(documented_id, load("res://src/grievances/evidence_record.gd").new(
		&"collapse_occurrence_2:fume_testimony", &"fume_testimony", &"nib", 2, 120, &"cave_in_prevention"
	))
	var documented_service: Variant = OrganizingServiceScript.new(
		workers,
		[],
		UnionResourcesScript.new(39, 15, 0, 1),
		authoritative_grievances
	)
	var earned: NegotiationState = composer.compose(
		documented_service.worker_views(),
		documented_service.grievance_views(),
		documented_service.resources_snapshot()
	)
	var earned_evidence := earned.first_evidence_id_for_kinds([&"fume_testimony"])
	t.equal(earned.evidence_strength(earned_evidence), 2, "authored documented evidence reaches the composer")
	var earned_offer := NegotiationResolver.bone_and_pick(earned).press(&"safety", earned_evidence)
	t.check(earned_offer.concession_rank > before_offer.concession_rank, "production-documented evidence improves the prepared deterministic offer")
	var earned_vote := _ratify_safety(earned)
	t.equal(earned_vote.eligibility_blockers, [], "production-documented evidence clears the safety eligibility boundary")
	t.check(earned_vote.ratified, "documented evidence unlocks and ratifies the prepared safety package")


static func _work_to_rule_preflights_every_negative_cost(t: TestCase) -> void:
	var documented := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	documented.phase = &"escalated"
	documented.action_history = [&"informal", &"grievance", &"petition"]
	var no_solidarity: Variant = OrganizingServiceScript.fixture_with_workers(
		[90, 90, 20], UnionResourcesScript.new(0, 5, 50, 1)
	)
	no_solidarity.register_grievance(documented)
	var solidarity_result: Variant = no_solidarity.execute(ActionProposalScript.new(&"work_to_rule", &"gas_case", 60))
	t.check(not solidarity_result.executed, "work-to-rule cannot partially spend missing solidarity")
	t.equal(solidarity_result.blocker, "requires 5 solidarity, has 0", "solidarity blocker is exact")
	t.equal(
		no_solidarity.resources_snapshot(),
		{"solidarity": 0, "treasury": 5, "public_support": 50, "organizer_capacity": 1},
		"solidarity rejection leaves every resource unchanged"
	)

	var no_public_support: Variant = OrganizingServiceScript.fixture_with_workers(
		[90, 90, 20], UnionResourcesScript.new(50, 5, 0, 1)
	)
	no_public_support.register_grievance(documented)
	var public_support_result: Variant = no_public_support.execute(ActionProposalScript.new(&"work_to_rule", &"gas_case", 60))
	t.check(not public_support_result.executed, "work-to-rule cannot partially spend missing public support")
	t.equal(public_support_result.blocker, "requires 2 public_support, has 0", "public support blocker is exact")
	t.equal(
		no_public_support.resources_snapshot(),
		{"solidarity": 50, "treasury": 5, "public_support": 0, "organizer_capacity": 1},
		"public support rejection leaves every resource unchanged"
	)


static func _resources_clamp_to_their_supported_bounds(t: TestCase) -> void:
	var resources := UnionResourcesScript.new(99, 3, 1, 1)
	resources.apply_delta(&"solidarity", 10)
	resources.apply_delta(&"solidarity", -500)
	resources.apply_delta(&"treasury", -500)
	resources.apply_delta(&"public_support", 500)
	resources.apply_delta(&"public_support", -500)
	resources.apply_delta(&"organizer_capacity", -5)

	t.equal(resources.snapshot(), {"solidarity": 0, "treasury": 0, "public_support": 0, "organizer_capacity": 0}, "shared resources never cross their floors or ceilings")


static func _service_copies_worker_and_grievance_inputs(t: TestCase) -> void:
	var worker := WorkerState.new(&"nib")
	worker.trust = 80
	worker.action_willingness = 80
	var documented := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"nib"])
	documented.phase = &"documented"
	var service: Variant = OrganizingServiceScript.new([worker], [documented])
	worker.trust = 0
	worker.action_willingness = 0
	documented.phase = &"reported"

	var forecast: Variant = service.forecast(ActionProposalScript.new(&"informal", &"gas_case", 60))
	t.equal(forecast.ready_workers, [&"nib"], "worker mutation outside the service cannot change consent")
	t.check(forecast.can_execute, "grievance copy remains documented and open after caller mutation")
	forecast.ready_workers.clear()
	t.equal(service.forecast(ActionProposalScript.new(&"informal", &"gas_case", 60)).ready_workers, [&"nib"], "forecast lists do not expose service state")


static func _escalation_is_sequential_idempotent_and_resolves_only_by_remedy(t: TestCase) -> void:
	var probe := GrievanceStateScript.new(&"sequence_case", &"unsafe_fumes", [&"worker_1"])
	var property_names: Array[StringName] = []
	for property in probe.get_property_list():
		property_names.append(StringName(property.name))
	t.check(property_names.has(&"action_history"), "grievance lifecycle exposes ordered escalation history")
	var service: Variant = OrganizingServiceScript.fixture_with_workers(
		[90, 90, 90], UnionResourcesScript.new(50, 10, 50, 1)
	)
	t.check(service.has_method("apply_remedy"), "organizing exposes a separate public remedy transition")
	if not property_names.has(&"action_history") or not service.has_method("apply_remedy"):
		return
	probe.phase = &"documented"
	service.register_grievance(probe)
	var initial_resources: Dictionary = service.resources_snapshot()
	var out_of_order: Dictionary = service.execute(ActionProposalScript.new(&"grievance", probe.id, 60))
	t.check(not out_of_order.executed, "formal filing cannot skip the authored informal step")
	t.equal(out_of_order.blocker, "next escalation step is informal", "out-of-order blocker names the next authored step")
	t.equal(service.resources_snapshot(), initial_resources, "failed out-of-order action changes no resources")

	var expected_resources := [
		{"solidarity": 52, "treasury": 10, "public_support": 50, "organizer_capacity": 1},
		{"solidarity": 53, "treasury": 10, "public_support": 50, "organizer_capacity": 1},
		{"solidarity": 51, "treasury": 10, "public_support": 52, "organizer_capacity": 1},
		{"solidarity": 46, "treasury": 5, "public_support": 50, "organizer_capacity": 1},
	]
	var expected_phases: Array[StringName] = [&"documented", &"submitted", &"escalated", &"escalated"]
	var actions: Array[StringName] = [&"informal", &"grievance", &"petition", &"work_to_rule"]
	for index in actions.size():
		var action := actions[index]
		var result: Dictionary = service.execute(ActionProposalScript.new(action, probe.id, 60))
		t.check(result.executed, "%s executes at its authored step" % action)
		var state: GrievanceState = service.grievance_view(probe.id)
		t.equal(state.action_history, actions.slice(0, index + 1), "%s appends exactly once to ordered action history" % action)
		t.equal(state.phase, expected_phases[index], "%s publishes its non-terminal lifecycle phase" % action)
		t.equal(service.resources_snapshot(), expected_resources[index], "%s applies its resource effect exactly once" % action)
		var after_first: Dictionary = service.resources_snapshot()
		var repeated: Dictionary = service.execute(ActionProposalScript.new(action, probe.id, 60))
		t.check(not repeated.executed, "%s repeat is idempotently rejected" % action)
		t.equal(service.resources_snapshot(), after_first, "%s repeat cannot reapply resources" % action)

	var escalated: GrievanceState = service.grievance_view(probe.id)
	t.equal(escalated.phase, &"escalated", "the full four-step path remains open pending settlement")
	t.equal(escalated.resolved_action, &"", "filing collective actions does not manufacture a resolution")
	var durable_before_remedy: Array[Dictionary] = service.grievance_views()
	var restored: Variant = OrganizingServiceScript.restore(service.worker_views(), durable_before_remedy, service.resources_snapshot())
	t.equal(restored.grievance_views(), durable_before_remedy, "save restoration preserves submitted/escalated phase and ordered history")

	var remedy: Dictionary = service.apply_remedy(probe.id, &"ventilation_repair")
	t.check(remedy.get("applied", false), "separate remedy transition settles the escalated case")
	var resolved: GrievanceState = service.grievance_view(probe.id)
	t.equal(resolved.phase, &"resolved", "remedy is the transition that marks a case resolved")
	t.equal(resolved.resolved_action, &"ventilation_repair", "resolved case records its actual remedy")
	t.equal(resolved.action_history, actions, "remedy preserves the complete escalation history")
	t.check(not service.apply_remedy(probe.id, &"second_remedy").get("applied", false), "resolved case rejects a repeated remedy")

	for terminal_phase in [&"expired", &"withdrawn"]:
		var terminal := GrievanceStateScript.new(StringName("%s_case" % terminal_phase), &"unsafe_fumes", [&"worker_1"])
		terminal.phase = terminal_phase
		var terminal_service: Variant = OrganizingServiceScript.fixture_with_workers([90])
		terminal_service.register_grievance(terminal)
		t.check(not terminal_service.execute(ActionProposalScript.new(&"informal", terminal.id, 60)).executed, "%s case rejects escalation" % terminal_phase)
		t.check(not terminal_service.apply_remedy(terminal.id, &"settlement").applied, "%s case rejects remedies" % terminal_phase)
