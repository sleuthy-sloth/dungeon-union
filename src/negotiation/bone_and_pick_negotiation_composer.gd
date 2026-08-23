class_name BoneAndPickNegotiationComposer
extends RefCounted

const PARTICIPATION_THRESHOLD := 50


func compose(worker_views: Array, grievance_views: Array, resources: Dictionary) -> NegotiationState:
	var evidence := _evidence_from(grievance_views)
	var priorities := {}
	var ready := 0
	var active := 0
	for raw_worker in worker_views:
		if not raw_worker is Dictionary:
			continue
		var worker: Dictionary = raw_worker
		if StringName(worker.get("employment_state", &"active")) != &"active":
			continue
		var worker_id := StringName(worker.get("id", &""))
		if worker_id.is_empty():
			continue
		active += 1
		var trust := clampi(int(worker.get("trust", 0)), 0, 100)
		var willingness := clampi(int(worker.get("action_willingness", 0)), 0, 100)
		if int((trust + willingness) / 2) >= PARTICIPATION_THRESHOLD:
			ready += 1
		priorities[worker_id] = {
			"trust": trust,
			"priorities": _normalized_priorities(worker.get("bargaining_priorities", {})),
		}
	var participation := int(round(100.0 * float(ready) / float(active))) if active > 0 else 0
	return NegotiationState.new(
		evidence,
		int(resources.get("solidarity", 0)),
		participation,
		int(resources.get("treasury", 0)),
		int(resources.get("public_support", 0)),
		priorities
	)


func _evidence_from(grievance_views: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary[StringName, bool] = {}
	for raw_grievance in grievance_views:
		if not raw_grievance is Dictionary:
			continue
		var grievance: Dictionary = raw_grievance
		if StringName(grievance.get("phase", &"reported")) not in [&"documented", &"submitted", &"escalated", &"resolved"]:
			continue
		for raw_record in grievance.get("evidence_records", []):
			if not raw_record is Dictionary:
				continue
			var record: Dictionary = raw_record
			var evidence_id := StringName(record.get("id", &""))
			if evidence_id.is_empty() or seen.has(evidence_id):
				continue
			seen[evidence_id] = true
			result.append(record.duplicate(true))
	return result


func _normalized_priorities(raw: Variant) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for issue in raw:
		result[StringName(issue)] = maxi(0, int(raw[issue]))
	return result
