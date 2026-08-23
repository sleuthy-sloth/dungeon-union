extends RefCounted


static func run(t: TestCase) -> void:
	var required := {
		"res://src/workers/workplace_simulation.gd": &"restore",
		"res://src/grievances/grievance_service.gd": &"restore",
		"res://src/organizing/organizing_service.gd": &"restore",
		"res://src/campaign/campaign_state.gd": &"restore",
	}
	var available := true
	for path in required:
		var script: GDScript = load(path)
		var found := false
		for method in script.get_script_method_list():
			if StringName(method.name) == required[path]:
				found = true
		t.check(found, "durable public restore API exists: %s.%s" % [path, required[path]])
		available = available and found
	if not available:
		return
	var worker_views: Array[Dictionary] = [
		{"id": &"nib", "fatigue": 73, "trust": 31, "action_willingness": 82, "employment_state": &"active", "bargaining_priorities": {&"safety": 3}},
	]
	var simulation: WorkplaceSimulation = load("res://src/workers/workplace_simulation.gd").call(&"restore", 91, {"tick": 37, "workers": worker_views})
	t.equal(simulation.snapshot(), {"tick": 37, "workers": worker_views}, "worker simulation restores every durable worker field and tick")
	var grievances := [
		{"id": &"reported", "issue": &"safety", "affected_workers": [&"nib"], "phase": &"reported", "evidence_score": 0, "evidence_records": [], "deadline_tick": 0, "action_history": [], "resolved_action": &""},
		{"id": &"documented", "issue": &"safety", "affected_workers": [&"nib"], "phase": &"documented", "evidence_score": 2, "evidence_records": [], "deadline_tick": 90, "action_history": [], "resolved_action": &""},
		{"id": &"resolved", "issue": &"safety", "affected_workers": [&"nib"], "phase": &"resolved", "evidence_score": 2, "evidence_records": [], "deadline_tick": 90, "action_history": [&"informal", &"grievance", &"petition"], "resolved_action": &"ventilation_repair"},
		{"id": &"expired", "issue": &"safety", "affected_workers": [&"nib"], "phase": &"expired", "evidence_score": 1, "evidence_records": [], "deadline_tick": 20, "action_history": [], "resolved_action": &""},
	]
	var grievance_service: GrievanceService = load("res://src/grievances/grievance_service.gd").call(&"restore", grievances, 37)
	t.equal(grievance_service.snapshot(), grievances, "grievance restore preserves reported/documented/resolved/expired phases and deadlines")
	var resources := {"solidarity": 33, "treasury": 7, "public_support": 19, "organizer_capacity": 4}
	var organizing: OrganizingService = load("res://src/organizing/organizing_service.gd").call(&"restore", worker_views, grievances, resources)
	t.equal(organizing.resources_snapshot(), resources, "organizing restore preserves modified resources")
	t.equal(organizing.worker_views(), worker_views, "organizing restore consumes authoritative copied worker views")
	var campaign_view := {"upgrade_points": 2, "upgrades": [&"legal_desk_1", &"print_shop_1"], "available_branches": CampaignState.BRANCHES.duplicate()}
	var campaign: CampaignState = load("res://src/campaign/campaign_state.gd").call(&"restore", campaign_view)
	t.equal(campaign.read_view(), campaign_view, "campaign restore preserves hall purchases and remaining points")
	var progressed_simulation := WorkplaceSimulation.create_fixture(91)
	for tick in 37:
		progressed_simulation.apply_tick()
	var progressed_director := WorkplaceDirector.fixture(91)
	progressed_director.set_workday(3)
	var started: EventDefinition = progressed_director.choose_and_start(360)
	var durable := {
		"schema_version": SaveService.SCHEMA_VERSION,
		"simulation": progressed_simulation.durable_snapshot(),
		"grievances": grievances,
		"resources": resources,
		"campaign": campaign_view,
		"negotiation": {"ratified": true, "yes_votes": [&"nib"], "no_votes": [], "strategy": &"safety_first"},
		"event_progress": progressed_director.durable_snapshot(),
	}
	var round_tripped := SaveService.round_trip_for_test(durable)
	var restored_simulation := WorkplaceSimulation.restore(91, round_tripped.simulation)
	var restored_grievances := GrievanceService.restore(round_tripped.grievances, 37)
	var restored_organizing := OrganizingService.restore(restored_simulation.snapshot().workers, restored_grievances.snapshot(), round_tripped.resources)
	var restored_campaign := CampaignState.restore(round_tripped.campaign)
	var restored_director := WorkplaceDirector.fixture(91)
	restored_director.restore_progress(round_tripped.event_progress)
	t.equal(restored_simulation.durable_snapshot(), durable.simulation, "SaveService round trip restores worker values, tick, and deterministic stream progression")
	t.equal(restored_grievances.snapshot(), grievances, "SaveService round trip restores every grievance lifecycle phase")
	t.equal(restored_organizing.resources_snapshot(), resources, "SaveService round trip restores modified organizing resources")
	t.equal(restored_campaign.read_view(), campaign_view, "SaveService round trip restores purchased union-hall branches")
	t.equal(round_tripped.negotiation, durable.negotiation, "SaveService round trip restores negotiated state without recomputation")
	t.equal(restored_director.durable_snapshot(), durable.event_progress, "SaveService round trip restores authored event pacing and active runtime progression")
	if started != null:
		progressed_director.complete_event(started.id)
		restored_director.complete_event(started.id)
		progressed_director.set_workday(4)
		restored_director.set_workday(4)
		var next_original := progressed_director.choose_and_start(540)
		var next_restored := restored_director.choose_and_start(540)
		t.equal(next_restored.id if next_restored != null else &"", next_original.id if next_original != null else &"", "restored event RNG continues the same authored sequence")
