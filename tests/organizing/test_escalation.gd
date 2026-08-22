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
	_work_to_rule_preflights_every_negative_cost(t)
	_resources_clamp_to_their_supported_bounds(t)
	_service_copies_worker_and_grievance_inputs(t)


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

	t.check(service.forecast(ActionProposalScript.new(&"informal", &"", 60)).can_execute, "informal action is available with one ready worker")
	t.check(service.forecast(ActionProposalScript.new(&"grievance", &"gas_case", 60)).can_execute, "documented grievances are executable")
	t.check(service.forecast(ActionProposalScript.new(&"petition", &"gas_case", 60)).can_execute, "a petition needs two ready workers")
	t.check(service.forecast(ActionProposalScript.new(&"work_to_rule", &"gas_case", 60)).can_execute, "a ready majority can work to rule")

	var missing_case: Variant = service.forecast(ActionProposalScript.new(&"grievance", &"missing", 60))
	t.check(not missing_case.can_execute, "grievance needs a documented case")
	t.equal(missing_case.blocker, "requires a documented grievance: missing", "missing case names the blocker")

	var thin_support: Variant = OrganizingServiceScript.fixture_with_workers([80, 25, 20])
	thin_support.register_grievance(case_state)
	var petition: Variant = thin_support.forecast(ActionProposalScript.new(&"petition", &"gas_case", 60))
	t.check(not petition.can_execute, "petition fails without two ready workers")
	t.equal(petition.blocker, "requires at least 2 ready workers", "participation blocker states its minimum")
	var no_fund: Variant = OrganizingServiceScript.fixture_with_workers([80, 75, 20])
	no_fund.register_grievance(case_state)
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
	documented.phase = &"documented"
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
	var composer: Variant = load("res://src/negotiation/bone_and_pick_negotiation_composer.gd").new()
	for action in [&"informal", &"grievance", &"petition", &"work_to_rule"]:
		var workers: Array = []
		for worker_id in [&"nib", &"brakka", &"clatter"]:
			var worker := WorkerState.new(worker_id)
			worker.trust = 55
			worker.action_willingness = 90
			worker.bargaining_priorities = {&"safety": 3}
			workers.append(worker)
		var case_state := GrievanceStateScript.new(StringName("%s_case" % action), &"cave_in_prevention", [&"nib"])
		if action != &"informal":
			case_state.phase = &"documented"
		var service: Variant = OrganizingServiceScript.new(workers, [case_state], UnionResourcesScript.new(40, 5, 2, 1))
		t.check(service.has_method("grievance_view") and service.has_method("grievance_views"), "organizing publishes authoritative copied grievance views")
		if not service.has_method("grievance_view") or not service.has_method("grievance_views"):
			continue
		var proposal := ActionProposalScript.new(action, case_state.id, 50)
		var first: Dictionary = service.execute(proposal)
		t.check(first.executed, "%s public execution commits its grievance transition" % action)
		var terminal: Variant = service.grievance_view(case_state.id)
		t.equal(terminal.phase, &"resolved", "%s leaves the authoritative grievance terminal" % action)
		t.equal(terminal.resolved_action, action, "%s records the committed action" % action)
		var after_first: Dictionary = service.resources_snapshot()
		var state_after_first: NegotiationState = composer.compose(service.worker_views(), service.grievance_views(), after_first)
		var vote_after_first := _ratify_safety(state_after_first)
		t.check(not service.register_grievance(case_state), "%s stale caller snapshot cannot reopen the authoritative grievance" % action)
		var repeated: Dictionary = service.execute(proposal)
		t.check(not repeated.executed, "%s second public execution is rejected" % action)
		t.equal(service.resources_snapshot(), after_first, "%s second public execution cannot change resources" % action)
		t.equal(_ratify_safety(composer.compose(service.worker_views(), service.grievance_views(), service.resources_snapshot())).ratified, vote_after_first.ratified, "%s repeat cannot flip negotiation" % action)
		if action == &"informal":
			t.equal(state_after_first.evidence_strength(&"fume_testimony"), 0, "informal public execution remains evidence-free")
			t.check(not vote_after_first.ratified, "evidence-free informal execution cannot ratify a package")


static func _ratify_safety(state: NegotiationState) -> Dictionary:
	var resolver := NegotiationResolver.bone_and_pick(state)
	return resolver.ratify({
		&"safety": resolver.press(&"safety", &"fume_testimony"),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", &"tool_ledger"),
	})


static func _work_to_rule_preflights_every_negative_cost(t: TestCase) -> void:
	var documented := GrievanceStateScript.new(&"gas_case", &"unsafe_fumes", [&"worker_1"])
	documented.phase = &"documented"
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

	var forecast: Variant = service.forecast(ActionProposalScript.new(&"grievance", &"gas_case", 60))
	t.equal(forecast.ready_workers, [&"nib"], "worker mutation outside the service cannot change consent")
	t.check(forecast.can_execute, "grievance copy remains documented after caller mutation")
	forecast.ready_workers.clear()
	t.equal(service.forecast(ActionProposalScript.new(&"grievance", &"gas_case", 60)).ready_workers, [&"nib"], "forecast lists do not expose service state")
