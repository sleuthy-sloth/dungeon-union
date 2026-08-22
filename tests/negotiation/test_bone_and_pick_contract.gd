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

	var evidence_state := NegotiationStateScript.new({&"fume_testimony": 1})
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
	var divided: Dictionary = resolver.ratify(safety_package)

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
	var approved: Dictionary = resolver.ratify(complete_package)
	t.equal(approved.yes_votes, [&"brakka", &"clatter", &"nib"], "a coherent package wins each named worker")
	t.equal(approved.no_votes, [], "the complete package has no opposing votes")
	t.check(approved.ratified, "a named-worker majority ratifies the package")
	t.equal(resolver.ratify(complete_package), approved, "ratification is deterministic")


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
	var vote: Dictionary = resolver.ratify(package)

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

	t.equal(resolver.press(&"safety", &"fume_testimony").employer_score, 2, "only non-empty string evidence IDs are normalized")
	var vote: Dictionary = resolver.ratify({&"safety": 2})
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


static func _contains_digit(value: String) -> bool:
	for digit in "0123456789":
		if value.contains(digit):
			return true
	return false
