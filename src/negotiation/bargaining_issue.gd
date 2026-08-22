class_name BargainingIssue
extends RefCounted

var _id: StringName
var _clauses: Array[Dictionary] = []
var _score_thresholds: Array[int] = []
var _relevant_support: Array[StringName] = []

var id: StringName:
	get:
		return _id
	set(_value):
		pass

var max_rank: int:
	get:
		return _clauses.size()
	set(_value):
		pass


func _init(
	issue_id: StringName,
	clauses: Array[Dictionary],
	score_thresholds: Array[int],
	relevant_support: Array[StringName] = []
) -> void:
	_id = issue_id
	_clauses = clauses.duplicate(true)
	_score_thresholds = score_thresholds.duplicate()
	_relevant_support = relevant_support.duplicate()


func concession_for_score(score: int) -> Dictionary:
	var rank := 0
	for index in _score_thresholds.size():
		if score >= _score_thresholds[index]:
			rank = index + 1
	return {
		"concession_rank": rank,
		"clause_id": clause_id_for_rank(rank),
	}


func clause_id_for_rank(rank: int) -> StringName:
	if rank <= 0 or rank > _clauses.size():
		return &""
	return StringName(_clauses[rank - 1].get("id", &""))


func accepts_support(support_id: StringName) -> bool:
	return _relevant_support.has(support_id)
