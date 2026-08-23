extends RefCounted

const NegotiationResolverScript = preload("res://src/negotiation/negotiation_resolver.gd")
const NegotiationStateScript = preload("res://src/negotiation/negotiation_state.gd")


static func run(t: TestCase) -> void:
	_evidence_strengthens_the_safety_demand(t)
	_every_earned_leverage_input_reaches_employer_evaluation(t)
	_employer_evaluation_is_deterministic_and_bounded_by_authored_clauses(t)
	_ratification_uses_named_priorities_and_trust(t)
	_resolver_snapshots_the_callers_leverage_state(t)
	_explanations_are_qualitative_without_hidden_arithmetic(t)
	_state_rejects_invalid_stable_id_keys(t)
	_malformed_nested_inputs_are_rejected_deterministically(t)
	_only_exact_resolver_issued_tentative_agreements_can_ratify(t)
	_missing_or_wrong_evidence_relevance_cannot_authorize_terms(t)
	_real_documented_evidence_issues_and_ratifies_a_valid_agreement(t)


static func _evidence_strengthens_the_safety_demand(t: TestCase) -> void:
	var resolver: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	var weak: Dictionary = resolver.press(&"safety", &"none")
	var strong: Dictionary = resolver.press(&"safety", &"fume_testimony")

	t.check(int(strong.concession_rank) > int(weak.concession_rank), "evidence strengthens safety demand")
	t.equal(weak.concession_rank, 1, "organizing leverage wins the basic safety clause")
	t.equal(strong.concession_rank, 2, "relevant testimony wins an improved safety clause")
	t.equal(strong.clause_id, &"ventilation_and_refusal", "the improved safety rank names its durable clause")


static func _every_earned_leverage_input_reaches_employer_evaluation(t: TestCase) -> void:
	var states := [
		NegotiationStateScript.new({}, 20, 0, 0, 0),
		NegotiationStateScript.new({}, 0, 20, 0, 0),
		NegotiationStateScript.new({}, 0, 0, 5, 0),
		NegotiationStateScript.new({}, 0, 0, 0, 25),
	]
	var input_names := ["solidarity", "participation", "treasury", "public support"]
	for index in states.size():
		var resolver: Variant = NegotiationResolverScript.bone_and_pick(states[index])
		t.equal(resolver.press(&"safety", &"none").employer_score, 1, "%s contributes to employer evaluation" % input_names[index])

	var evidence_state := NegotiationStateScript.new([{
		"id": &"fume_testimony", "kind": &"fume_testimony", "source": &"drusk",
		"reliability": 1, "deadline_tick": 300, "relevant_issue": &"lantern_fume_exposure",
	}])
	var evidence_resolver: Variant = NegotiationResolverScript.bone_and_pick(evidence_state)
	t.equal(evidence_resolver.press(&"safety", &"fume_testimony").employer_score, 2, "relevant evidence contributes independently to employer evaluation")
	var no_evidence: Variant = NegotiationResolverScript.bone_and_pick(NegotiationStateScript.new())
	t.equal(no_evidence.press(&"safety", &"fume_testimony").employer_score, no_evidence.press(&"safety", &"none").employer_score, "a support ID without evidence adds no leverage")


static func _employer_evaluation_is_deterministic_and_bounded_by_authored_clauses(t: TestCase) -> void:
	var first: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	var second: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	var first_offer: Dictionary = first.press(&"safety", &"fume_testimony")
	var second_offer: Dictionary = second.press(&"safety", &"fume_testimony")

	t.equal(first_offer, second_offer, "the same state and support produce the same employer offer")
	t.equal(first.press(&"schedule", &"none").clause_id, &"alarm_schedule_protection", "schedule protection is an authored concession")
	t.equal(first.press(&"tool_maintenance", &"none").clause_id, &"paid_tool_maintenance", "tool maintenance pay is an authored concession")
	t.equal(first.press(&"missing", &"none").concession_rank, 0, "unknown issues cannot create a concession")
	t.equal(first.press(&"safety", &"tool_ledger").concession_rank, 1, "irrelevant evidence cannot improve safety language")


static func _ratification_uses_named_priorities_and_trust(t: TestCase) -> void:
	var resolver: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	var safety_package := {
		&"safety": resolver.press(&"safety", &"fume_testimony"),
	}
	var divided: Dictionary = _issue_and_ratify(resolver, safety_package)

	t.equal(divided.yes_votes, [&"nib"], "the worker prioritizing safety votes yes")
	t.equal(divided.no_votes, [&"brakka", &"clatter"], "workers with unmet named priorities vote no")
	t.check(String(divided.explanations.nib).contains("safety"), "vote explanations name the decisive priority")
	t.check(String(divided.explanations.nib).contains("trust"), "vote explanations expose trust as a factor")
	t.check(not divided.ratified, "a package without majority support is rejected")

	var complete_package := {
		&"safety": resolver.press(&"safety", &"fume_testimony"),
		&"schedule": resolver.press(&"schedule", &"none"),
		&"tool_maintenance": resolver.press(&"tool_maintenance", &"none"),
	}
	var agreement: Dictionary = _issue(resolver, complete_package)
	var approved: Dictionary = resolver.ratify(agreement)
	t.equal(approved.yes_votes, [&"brakka", &"clatter", &"nib"], "a coherent package wins each named worker")
	t.equal(approved.no_votes, [], "the complete package has no opposing votes")
	t.check(approved.ratified, "a named-worker majority ratifies the package")
	t.equal(resolver.ratify(agreement.duplicate(true)), approved, "a copied exact issued agreement ratifies deterministically")


static func _resolver_snapshots_the_callers_leverage_state(t: TestCase) -> void:
	var state := NegotiationStateScript.new()
	var resolver: Variant = NegotiationResolverScript.bone_and_pick(state)
	var before: Dictionary = resolver.press(&"safety", &"none")
	state.solidarity = 100
	state.participation = 100
	state.treasury = 100
	state.public_support = 100

	t.equal(resolver.press(&"safety", &"none"), before, "caller mutation cannot change an existing resolver outcome")


static func _explanations_are_qualitative_without_hidden_arithmetic(t: TestCase) -> void:
	var resolver: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	var package := {&"safety": resolver.press(&"safety", &"fume_testimony")}
	var vote: Dictionary = _issue_and_ratify(resolver, package)

	for worker_id in vote.explanations:
		var explanation := String(vote.explanations[worker_id])
		t.check(explanation.contains("decisive priority:"), "%s explanation names its decisive priority" % worker_id)
		t.check(explanation.contains("positive factors:"), "%s explanation gives broad positive factors" % worker_id)
		t.check(explanation.contains("negative factors:"), "%s explanation gives broad negative factors" % worker_id)
		t.check(not _contains_digit(explanation), "%s explanation does not disclose hidden numeric arithmetic" % worker_id)


static func _state_rejects_invalid_stable_id_keys(t: TestCase) -> void:
	var worker_record := {"trust": 90, "priorities": {7: 99, null: 99, "": 99, "safety": 3}}
	var state := NegotiationStateScript.new(
		{7: 99, null: 99, "": 99, "fume_testimony": 1},
		0,
		0,
		0,
		0,
		{7: worker_record, null: worker_record, "": worker_record, "nib": worker_record}
	)
	var resolver: Variant = NegotiationResolverScript.bone_and_pick(state)

	t.equal(state.evidence_strength(&"fume_testimony"), 1, "only non-empty string evidence IDs are normalized")
	t.equal(resolver.press(&"safety", &"fume_testimony").employer_score, 0, "legacy aggregate evidence without authored relevance cannot create bargaining leverage")
	var vote: Dictionary = _issue_and_ratify(resolver, {&"safety": resolver.press(&"safety", &"fume_testimony")})
	t.equal(vote.yes_votes, [&"nib"], "only non-empty string worker IDs enter the electorate")
	t.equal(vote.no_votes, [], "numeric, null, and empty worker IDs are rejected")
	t.check(String(vote.explanations.nib).contains("decisive priority: safety"), "only valid priority IDs influence the explanation")


static func _malformed_nested_inputs_are_rejected_deterministically(t: TestCase) -> void:
	var malformed_state := NegotiationStateScript.new(
		{&"fume_testimony": "strong"},
		0,
		0,
		0,
		0,
		{&"nib": "not a worker record", &"brakka": {"trust": "high", "priorities": "safety"}}
	)
	var resolver: Variant = NegotiationResolverScript.bone_and_pick(malformed_state)
	t.equal(resolver.press(&"safety", &"fume_testimony").employer_score, 0, "malformed evidence contributes no leverage")
	var vote: Dictionary = resolver.ratify({&"safety": {"concession_rank": "maximum"}})
	t.equal(vote.yes_votes, [], "malformed worker and package values cannot manufacture yes votes")
	t.equal(vote.no_votes, [], "malformed worker records are excluded from the electorate")


static func _only_exact_resolver_issued_tentative_agreements_can_ratify(t: TestCase) -> void:
	var resolver: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	t.check(resolver.has_method("issue_tentative_agreement"), "resolver exposes an issued tentative-agreement boundary")
	if not resolver.has_method("issue_tentative_agreement"):
		return
	var complete_terms := {
		&"safety": resolver.press(&"safety", &"fume_testimony"),
		&"schedule": resolver.press(&"schedule", &""),
		&"tool_maintenance": resolver.press(&"tool_maintenance", &"tool_ledger"),
	}
	var issued: Dictionary = resolver.issue_tentative_agreement(complete_terms)
	t.check(not issued.is_empty(), "resolver issues terms composed from its own exact offers")
	var accepted_copy: Dictionary = resolver.ratify(issued.duplicate(true))
	t.check(accepted_copy.ratified, "an unchanged copied issued agreement can ratify")

	var forged_max := {
		&"safety": {"concession_rank": 3, "clause_id": &"worker_safety_committee", "support_id": &"fume_testimony"},
	}
	var forged_vote: Dictionary = resolver.ratify(forged_max)
	t.check(not forged_vote.ratified, "caller-forged maximum safety terms are rejected")
	t.equal(forged_vote.agreement_error, "tentative agreement was not issued by this resolver", "unissued package rejection is deterministic")

	var altered_rank := issued.duplicate(true)
	altered_rank.safety["concession_rank"] = 3
	t.check(not resolver.ratify(altered_rank).ratified, "altering an issued concession rank invalidates the agreement")
	var altered_clause := issued.duplicate(true)
	altered_clause.safety["clause_id"] = &"invented_clause"
	t.check(not resolver.ratify(altered_clause).ratified, "altering an issued clause ID invalidates the agreement")

	var foreign: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	t.check(not foreign.ratify(issued.duplicate(true)).ratified, "an agreement issued by another resolver is rejected")
	var newer: Dictionary = resolver.issue_tentative_agreement(complete_terms)
	t.check(not resolver.ratify(issued).ratified, "a superseded tentative agreement is stale")
	t.check(resolver.ratify(newer.duplicate(true)).ratified, "the newest exact issued agreement remains valid")

	var irrelevant_terms := {
		&"safety": resolver.press(&"safety", &"tool_ledger"),
	}
	var irrelevant_agreement: Dictionary = resolver.issue_tentative_agreement(irrelevant_terms)
	var irrelevant_vote: Dictionary = resolver.ratify(irrelevant_agreement)
	t.check(not irrelevant_vote.ratified, "irrelevant evidence cannot authorize a safety agreement")
	t.equal(irrelevant_vote.eligibility_blockers, [&"safety"], "irrelevant cited evidence names the blocked issue")


static func _real_documented_evidence_issues_and_ratifies_a_valid_agreement(t: TestCase) -> void:
	var probe: Variant = NegotiationResolverScript.bone_and_pick_fixture()
	if not probe.has_method("issue_tentative_agreement"):
		return
	var grievance_service := GrievanceService.new()
	var occurrence_id := grievance_service.report(IncidentRecord.new(
		&"lantern_fumes@00000060", &"lantern_fume_exposure", [&"drusk"], 60
	))
	var evidence_id := &"lantern_fumes@00000060:fume_testimony"
	grievance_service.add_evidence(occurrence_id, load("res://src/grievances/evidence_record.gd").new(
		evidence_id, &"fume_testimony", &"drusk", 2, 300, &"lantern_fume_exposure"
	))
	var workers := []
	for worker_id in [&"nib", &"brakka", &"clatter"]:
		workers.append({
			"id": worker_id,
			"employment_state": &"active",
			"trust": 60,
			"action_willingness": 90,
			"bargaining_priorities": {&"safety": 3},
		})
	var composer: Variant = load("res://src/negotiation/bone_and_pick_negotiation_composer.gd").new()
	var state: NegotiationState = composer.compose(
		workers,
		grievance_service.snapshot(),
		{"solidarity": 39, "treasury": 15, "public_support": 0, "organizer_capacity": 1}
	)
	t.equal(state.evidence_strength(evidence_id), 2, "real documented evidence reaches negotiation under its own ID")
	var resolver: Variant = NegotiationResolverScript.bone_and_pick(state)
	var offer: Dictionary = resolver.press(&"safety", evidence_id)
	t.check(int(offer.concession_rank) >= 2, "real relevant evidence improves the issued safety offer")
	var agreement: Dictionary = resolver.issue_tentative_agreement({&"safety": offer})
	var vote: Dictionary = resolver.ratify(agreement.duplicate(true))
	t.equal(vote.eligibility_blockers, [], "real cited evidence clears agreement eligibility")
	t.check(vote.ratified, "real documented evidence leads to a valid issued ratification")


static func _missing_or_wrong_evidence_relevance_cannot_authorize_terms(t: TestCase) -> void:
	for relevance in [&"", &"maintenance_pay"]:
		var evidence_id := StringName("fume_%s" % ("missing" if relevance.is_empty() else "wrong"))
		var state := NegotiationStateScript.new([{
			"id": evidence_id,
			"kind": &"fume_testimony",
			"source": &"nib",
			"reliability": 2,
			"deadline_tick": 300,
			"relevant_issue": relevance,
		}], 100, 0, 5, 0)
		var resolver: Variant = NegotiationResolverScript.bone_and_pick(state)
		var offer: Dictionary = resolver.press(&"safety", evidence_id)
		t.equal(offer.employer_score, 6, "safety cannot count fume evidence with %s relevance" % ("missing" if relevance.is_empty() else "wrong"))
		var agreement: Dictionary = resolver.issue_tentative_agreement({&"safety": offer})
		t.equal(resolver.ratify(agreement).eligibility_blockers, [&"safety"], "safety terms reject fume evidence with %s relevance" % ("missing" if relevance.is_empty() else "wrong"))


static func _issue(resolver: Variant, terms: Dictionary) -> Dictionary:
	return resolver.issue_tentative_agreement(terms) if resolver.has_method("issue_tentative_agreement") else terms


static func _issue_and_ratify(resolver: Variant, terms: Dictionary) -> Dictionary:
	return resolver.ratify(_issue(resolver, terms))


static func _contains_digit(value: String) -> bool:
	for digit in "0123456789":
		if value.contains(digit):
			return true
	return false
