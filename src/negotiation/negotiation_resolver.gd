class_name NegotiationResolver
extends RefCounted

const BargainingIssueScript = preload("res://src/negotiation/bargaining_issue.gd")
const NegotiationStateScript = preload("res://src/negotiation/negotiation_state.gd")

const RATIFICATION_SCORE := 80

var _state: NegotiationStateScript
var _issues: Dictionary[StringName, BargainingIssueScript] = {}
var _issued_offers: Dictionary[StringName, Dictionary] = {}
var _current_agreement: Dictionary = {}
var _agreement_generation := 0


func _init(state: NegotiationStateScript, issues: Array[BargainingIssueScript]) -> void:
	_state = NegotiationStateScript.new() if state == null else state.normalized_copy()
	for issue in issues:
		if issue != null and not issue.id.is_empty():
			_issues[issue.id] = issue


static func bone_and_pick_fixture() -> NegotiationResolver:
	var state := NegotiationStateScript.new(
		[
			{"id": &"fume_testimony", "kind": &"fume_testimony", "source": &"drusk", "reliability": 3, "deadline_tick": 300, "relevant_issue": &"lantern_fume_exposure"},
			{"id": &"tool_ledger", "kind": &"tool_ledger", "source": &"repair_ledger", "reliability": 2, "deadline_tick": 300, "relevant_issue": &"maintenance_pay"},
		],
		50,
		60,
		10,
		40,
		{
			&"nib": {"trust": 67, "priorities": {&"safety": 3, &"schedule": 1, &"tool_maintenance": 1}},
			&"brakka": {"trust": 55, "priorities": {&"safety": 1, &"schedule": 3, &"tool_maintenance": 1}},
			&"clatter": {"trust": 45, "priorities": {&"safety": 1, &"schedule": 1, &"tool_maintenance": 3}},
		}
	)
	return bone_and_pick(state)


static func bone_and_pick(state: NegotiationStateScript) -> NegotiationResolver:
	var issues: Array[BargainingIssueScript] = [
		BargainingIssueScript.new(
			&"safety",
			[
				{"id": &"basic_safety_inspections"},
				{"id": &"ventilation_and_refusal"},
				{"id": &"worker_safety_committee"},
			],
			[6, 10, 14],
			[&"fume_testimony", &"shoring_testimony"],
			true,
			[&"cave_in_prevention", &"lantern_fume_exposure", &"unsafe_fumes"]
		),
		BargainingIssueScript.new(
			&"schedule",
			[{"id": &"alarm_schedule_protection"}],
			[8]
		),
		BargainingIssueScript.new(
			&"tool_maintenance",
			[{"id": &"paid_tool_maintenance"}],
			[8],
			[&"tool_ledger", &"tool_testimony"],
			false,
			[&"maintenance_pay"]
		),
	]
	return load("res://src/negotiation/negotiation_resolver.gd").new(state, issues)


func press(issue_id: StringName, support_id: StringName) -> Dictionary:
	var issue: BargainingIssueScript = _issues.get(issue_id)
	if issue == null:
		return {
			"issue_id": issue_id,
			"support_id": support_id,
			"concession_rank": 0,
			"clause_id": &"",
			"employer_score": 0,
		}
	var score := _base_leverage()
	var evidence := _state.evidence_record(support_id)
	if not evidence.is_empty() and issue.accepts_evidence(
		StringName(evidence.get("kind", &"")), StringName(evidence.get("relevant_issue", &""))
	):
		var evidence_strength := _state.evidence_strength(support_id)
		if evidence_strength > 0:
			score += evidence_strength + 1
	var concession := issue.concession_for_score(score)
	var offer_id := StringName("%s|%s" % [issue_id, support_id])
	var offer := {
		"issue_id": issue_id,
		"support_id": support_id,
		"evidence_id": support_id,
		"concession_rank": concession.concession_rank,
		"clause_id": concession.clause_id,
		"employer_score": score,
		"_offer_id": offer_id,
	}
	_issued_offers[offer_id] = offer.duplicate(true)
	return offer


func issue_tentative_agreement(terms: Dictionary) -> Dictionary:
	if terms.is_empty():
		return {}
	var issued_terms := {}
	for raw_issue_id in terms:
		if typeof(raw_issue_id) != TYPE_STRING and typeof(raw_issue_id) != TYPE_STRING_NAME:
			return {}
		var issue_id := StringName(raw_issue_id)
		if not _issues.has(issue_id):
			return {}
		var raw_term: Variant = terms[raw_issue_id]
		if not raw_term is Dictionary:
			return {}
		var term: Dictionary = raw_term
		var offer_id := StringName(term.get("_offer_id", &""))
		if offer_id.is_empty() or not _issued_offers.has(offer_id) or _issued_offers[offer_id] != term:
			return {}
		if StringName(term.get("issue_id", &"")) != issue_id:
			return {}
		issued_terms[issue_id] = term.duplicate(true)
	_agreement_generation += 1
	issued_terms["_issued_agreement_id"] = StringName("agreement_%d" % _agreement_generation)
	issued_terms["_issuer_token"] = get_instance_id()
	_current_agreement = issued_terms.duplicate(true)
	return issued_terms.duplicate(true)


func ratify(package: Dictionary) -> Dictionary:
	if package.is_empty() or _current_agreement.is_empty() or package != _current_agreement:
		return {
			"ratified": false,
			"yes_votes": [],
			"no_votes": [],
			"explanations": {},
			"eligibility_blockers": [&"tentative_agreement"],
			"agreement_error": "tentative agreement was not issued by this resolver",
		}
	var yes_votes: Array[StringName] = []
	var no_votes: Array[StringName] = []
	var explanations: Dictionary[StringName, String] = {}
	var eligibility_blockers := _earned_evidence_blockers(package)
	for worker_id in _state.worker_ids():
		var priorities := _state.priorities_for(worker_id)
		var trust := _state.worker_trust(worker_id)
		var package_score := _package_support_score(priorities, package)
		var score := trust + package_score
		var votes_yes := score >= RATIFICATION_SCORE
		if votes_yes:
			yes_votes.append(worker_id)
		else:
			no_votes.append(worker_id)
		explanations[worker_id] = _qualitative_explanation(priorities, package, trust, votes_yes)
	return {
		"ratified": eligibility_blockers.is_empty() and yes_votes.size() > no_votes.size(),
		"yes_votes": yes_votes,
		"no_votes": no_votes,
		"explanations": explanations,
		"eligibility_blockers": eligibility_blockers,
		"agreement_error": "",
	}


func _earned_evidence_blockers(package: Dictionary) -> Array[StringName]:
	var blockers: Array[StringName] = []
	for raw_issue_id in package:
		if typeof(raw_issue_id) != TYPE_STRING and typeof(raw_issue_id) != TYPE_STRING_NAME:
			continue
		var issue_id := StringName(raw_issue_id)
		var issue: BargainingIssueScript = _issues.get(issue_id)
		if issue == null or not issue.requires_earned_evidence() or _package_rank(package, issue_id) <= 0:
			continue
		if issue.relevant_support_ids().is_empty():
			continue
		var term: Variant = package.get(issue_id, {})
		var support_id := StringName(term.get("evidence_id", &"")) if term is Dictionary else &""
		var evidence := _state.evidence_record(support_id)
		var has_earned_evidence := not evidence.is_empty() and _state.evidence_strength(support_id) > 0 and issue.accepts_evidence(
			StringName(evidence.get("kind", &"")), StringName(evidence.get("relevant_issue", &""))
		)
		if not has_earned_evidence:
			blockers.append(issue_id)
	blockers.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return blockers


func _base_leverage() -> int:
	return (
		int(_state.solidarity / 20)
		+ int(_state.participation / 20)
		+ mini(4, int(_state.treasury / 5))
		+ int(_state.public_support / 25)
	)


func _package_support_score(priorities: Dictionary, package: Dictionary) -> int:
	var score := 0
	for issue_id in priorities:
		var issue: BargainingIssueScript = _issues.get(StringName(issue_id))
		if issue == null or issue.max_rank == 0:
			continue
		var rank := _package_rank(package, StringName(issue_id))
		var weight := maxi(0, int(priorities[issue_id]))
		score += int(round(float(weight * 10 * rank) / float(issue.max_rank)))
	return score


func _package_rank(package: Dictionary, issue_id: StringName) -> int:
	var issue: BargainingIssueScript = _issues.get(issue_id)
	if issue == null:
		return 0
	var term: Variant = package.get(issue_id, 0)
	var raw_rank: Variant = term.get("concession_rank", 0) if term is Dictionary else term
	if typeof(raw_rank) != TYPE_INT and typeof(raw_rank) != TYPE_FLOAT:
		return 0
	var rank := int(raw_rank)
	return clampi(rank, 0, issue.max_rank)


func _strongest_priority(priorities: Dictionary) -> StringName:
	var ids: Array[StringName] = []
	for issue_id in priorities:
		ids.append(StringName(issue_id))
	ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		var left_weight := int(priorities.get(left, 0))
		var right_weight := int(priorities.get(right, 0))
		if left_weight == right_weight:
			return String(left) < String(right)
		return left_weight > right_weight
	)
	return ids[0] if not ids.is_empty() else &"none"


func _qualitative_explanation(
	priorities: Dictionary,
	package: Dictionary,
	trust: int,
	votes_yes: bool
) -> String:
	var decisive_priority := _strongest_priority(priorities)
	var positive_factors: Array[String] = []
	var negative_factors: Array[String] = []
	if trust >= 65:
		positive_factors.append("strong union trust")
	elif trust >= 45:
		positive_factors.append("some union trust")
		negative_factors.append("union trust remains mixed")
	else:
		negative_factors.append("weak union trust")
	var decisive_issue: BargainingIssueScript = _issues.get(decisive_priority)
	var decisive_rank := _package_rank(package, decisive_priority)
	if decisive_issue == null or decisive_rank == 0:
		negative_factors.append("decisive priority remains unmet")
	elif decisive_rank >= decisive_issue.max_rank:
		positive_factors.append("decisive priority is fully addressed")
	else:
		positive_factors.append("decisive priority is partly addressed")
		negative_factors.append("strongest available protection was not secured")
	var supporting_addressed := false
	var supporting_unmet := false
	for issue_id in priorities:
		if StringName(issue_id) == decisive_priority or int(priorities[issue_id]) <= 0:
			continue
		if _package_rank(package, StringName(issue_id)) > 0:
			supporting_addressed = true
		else:
			supporting_unmet = true
	if supporting_addressed:
		positive_factors.append("supporting priorities receive protection")
	if supporting_unmet:
		negative_factors.append("supporting priorities remain unmet")
	if positive_factors.is_empty():
		positive_factors.append("no broad positive factor")
	if negative_factors.is_empty():
		negative_factors.append("no broad negative factor")
	return "%s — decisive priority: %s; positive factors: %s; negative factors: %s" % [
		"yes" if votes_yes else "no",
		decisive_priority,
		", ".join(positive_factors),
		", ".join(negative_factors),
	]
