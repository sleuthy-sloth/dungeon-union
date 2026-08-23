class_name NegotiationState
extends RefCounted

var solidarity: int
var participation: int
var treasury: int
var public_support: int

var _evidence: Dictionary[StringName, Dictionary] = {}
var _workers: Dictionary = {}


func _init(
	evidence: Variant = {},
	initial_solidarity: int = 0,
	initial_participation: int = 0,
	initial_treasury: int = 0,
	initial_public_support: int = 0,
	worker_priorities: Dictionary = {}
) -> void:
	_import_evidence(evidence)
	solidarity = clampi(initial_solidarity, 0, 100)
	participation = clampi(initial_participation, 0, 100)
	treasury = maxi(0, initial_treasury)
	public_support = clampi(initial_public_support, 0, 100)
	for worker_id in worker_priorities:
		var normalized_worker_id := _normalize_stable_id(worker_id)
		if normalized_worker_id.is_empty():
			continue
		var raw_worker: Variant = worker_priorities[worker_id]
		if not raw_worker is Dictionary:
			continue
		var worker: Dictionary = raw_worker
		var raw_trust: Variant = worker.get("trust", 0)
		var raw_priorities: Variant = worker.get("priorities", {})
		if (typeof(raw_trust) != TYPE_INT and typeof(raw_trust) != TYPE_FLOAT) or not raw_priorities is Dictionary:
			continue
		var priorities: Dictionary = {}
		for issue_id in raw_priorities:
			var normalized_issue_id := _normalize_stable_id(issue_id)
			if normalized_issue_id.is_empty():
				continue
			var weight: Variant = raw_priorities[issue_id]
			if typeof(weight) == TYPE_INT or typeof(weight) == TYPE_FLOAT:
				priorities[normalized_issue_id] = maxi(0, int(weight))
		_workers[normalized_worker_id] = {
			"trust": clampi(int(raw_trust), 0, 100),
			"priorities": priorities,
		}


func evidence_strength(evidence_id: StringName) -> int:
	return maxi(0, int(_evidence.get(evidence_id, {}).get("reliability", 0)))


func evidence_record(evidence_id: StringName) -> Dictionary:
	return _evidence.get(evidence_id, {}).duplicate(true)


func evidence_ids() -> Array[StringName]:
	var ids: Array[StringName] = _evidence.keys()
	ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return ids


func first_evidence_id_for_kinds(kinds: Array[StringName]) -> StringName:
	for evidence_id in evidence_ids():
		if kinds.has(StringName(_evidence[evidence_id].get("kind", &""))) and evidence_strength(evidence_id) > 0:
			return evidence_id
	return &""


func worker_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for worker_id in _workers:
		ids.append(StringName(worker_id))
	ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return ids


func worker_trust(worker_id: StringName) -> int:
	var raw_worker: Variant = _workers.get(worker_id, {})
	if not raw_worker is Dictionary:
		return 0
	var worker: Dictionary = raw_worker
	return clampi(int(worker.get("trust", 0)), 0, 100)


func priorities_for(worker_id: StringName) -> Dictionary:
	var raw_worker: Variant = _workers.get(worker_id, {})
	if not raw_worker is Dictionary:
		return {}
	var worker: Dictionary = raw_worker
	var raw_priorities: Variant = worker.get("priorities", {})
	if not raw_priorities is Dictionary:
		return {}
	var priorities: Dictionary = raw_priorities
	return priorities.duplicate(true)


func normalized_copy() -> NegotiationState:
	return load("res://src/negotiation/negotiation_state.gd").new(
		_evidence.values(),
		solidarity,
		participation,
		treasury,
		public_support,
		_workers
	)


func _import_evidence(evidence: Variant) -> void:
	if evidence is Dictionary:
		for support_id in evidence:
			var normalized_id := _normalize_stable_id(support_id)
			var strength: Variant = evidence[support_id]
			if normalized_id.is_empty() or (typeof(strength) != TYPE_INT and typeof(strength) != TYPE_FLOAT):
				continue
			_add_evidence_view({
				"id": normalized_id,
				"kind": normalized_id,
				"source": normalized_id,
				"reliability": maxi(0, int(strength)),
				"deadline_tick": 0,
				"relevant_issue": &"",
			})
	elif evidence is Array:
		for raw_record in evidence:
			if raw_record is EvidenceRecord:
				_add_evidence_view(raw_record.to_dictionary())
			elif raw_record is Dictionary:
				_add_evidence_view(raw_record)


func _add_evidence_view(raw: Dictionary) -> void:
	var evidence_id := _normalize_stable_id(raw.get("id", &""))
	var evidence_kind := _normalize_stable_id(raw.get("kind", &""))
	var source := _normalize_stable_id(raw.get("source", &""))
	var raw_reliability: Variant = raw.get("reliability", 0)
	if evidence_id.is_empty() or evidence_kind.is_empty() or source.is_empty():
		return
	if typeof(raw_reliability) != TYPE_INT and typeof(raw_reliability) != TYPE_FLOAT:
		return
	_evidence[evidence_id] = {
		"id": evidence_id,
		"kind": evidence_kind,
		"source": source,
		"reliability": maxi(0, int(raw_reliability)),
		"deadline_tick": maxi(0, int(raw.get("deadline_tick", 0))),
		"relevant_issue": _normalize_stable_id(raw.get("relevant_issue", &"")),
	}


static func _normalize_stable_id(value: Variant) -> StringName:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return &""
	var text := String(value).strip_edges()
	return StringName(text) if not text.is_empty() else &""
