extends RefCounted

const COMPOSER_PATH := "res://src/negotiation/bone_and_pick_negotiation_composer.gd"


static func run(t: TestCase) -> void:
	var catalog: ContentCatalog = load("res://content/bone_and_pick/catalog.tres")
	var has_authored_priorities := true
	for worker in catalog.worker_items:
		var property_names: Array[StringName] = []
		for property in worker.get_property_list():
			property_names.append(StringName(property.name))
		if not property_names.has(&"initial_trust") or not property_names.has(&"initial_action_willingness") or not property_names.has(&"bargaining_priorities"):
			has_authored_priorities = false
			break
	t.check(has_authored_priorities, "every worker definition exposes authored trust, willingness, and bargaining priorities")
	t.check(ResourceLoader.exists(COMPOSER_PATH), "production negotiation composer exists")
	if not has_authored_priorities or not ResourceLoader.exists(COMPOSER_PATH):
		return
	var composer: Variant = load(COMPOSER_PATH).new()
	var workers := [
		{"id": &"nib", "employment_state": &"active", "trust": 40, "action_willingness": 40, "bargaining_priorities": {&"safety": 3}},
		{"id": &"brakka", "employment_state": &"active", "trust": 60, "action_willingness": 60, "bargaining_priorities": {&"schedule": 3}},
	]
	var resources := {"solidarity": 20, "treasury": 0, "public_support": 0, "organizer_capacity": 1}
	var no_evidence: NegotiationState = composer.compose(workers, [], resources)
	var evidence: NegotiationState = composer.compose(workers, [{"issue": &"lantern_fume_exposure", "phase": &"documented", "evidence_score": 2}], resources)
	var richer: NegotiationState = composer.compose(workers, [], resources.merged({"treasury": 10}, true))
	var willing_workers := workers.duplicate(true)
	willing_workers[0]["action_willingness"] = 100
	var willing: NegotiationState = composer.compose(willing_workers, [], resources)
	var trusted_workers := workers.duplicate(true)
	trusted_workers[0]["trust"] = 90
	var trusted: NegotiationState = composer.compose(trusted_workers, [], resources)
	t.equal(no_evidence.evidence_strength(&"fume_testimony"), 0, "no grievance yields no evidence")
	t.equal(evidence.evidence_strength(&"fume_testimony"), 2, "documented grievance independently changes evidence")
	t.check(richer.treasury > no_evidence.treasury, "resource counterfactual independently changes treasury")
	t.check(willing.participation > no_evidence.participation, "willingness counterfactual independently changes participation")
	t.check(trusted.worker_trust(&"nib") > no_evidence.worker_trust(&"nib"), "named-worker trust counterfactual independently changes ratification trust")
