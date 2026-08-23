class_name EventDefinition
extends Resource

const GRIEVANCE_KIND: StringName = &"grievance"
const POSITIVE_KIND: StringName = &"positive"
const VALID_KINDS: Array[StringName] = [GRIEVANCE_KIND, POSITIVE_KIND]

@export var id: StringName
@export var family: StringName
@export var issue: StringName
@export var event_kind: StringName = GRIEVANCE_KIND
@export var minimum_tick := 0
@export var major := true
@export var required_worker_tags: Array[StringName]
@export var presentation_title := ""
@export_multiline var presentation_description := ""
@export var visual_pattern := ""
@export var evidence_kind: StringName
@export var evidence_source: StringName
@export_range(0, 10, 1) var evidence_reliability := 0
@export_range(0, 100000, 1) var evidence_window_ticks := 0


func runtime_copy() -> EventDefinition:
	var copied := EventDefinition.new()
	copied.id = id
	copied.family = family
	copied.issue = issue
	copied.event_kind = event_kind
	copied.minimum_tick = minimum_tick
	copied.major = major
	copied.required_worker_tags = required_worker_tags.duplicate()
	copied.presentation_title = presentation_title
	copied.presentation_description = presentation_description
	copied.visual_pattern = visual_pattern
	copied.evidence_kind = evidence_kind
	copied.evidence_source = evidence_source
	copied.evidence_reliability = evidence_reliability
	copied.evidence_window_ticks = evidence_window_ticks
	return copied


func occurrence_view(
	occurrence_id: StringName,
	affected_worker_ids: Array[StringName],
	started_tick: int
) -> Dictionary:
	var resolved_source := evidence_source
	if resolved_source == &"affected_worker" and not affected_worker_ids.is_empty():
		resolved_source = affected_worker_ids[0]
	var evidence_id := StringName("%s:%s" % [occurrence_id, evidence_kind]) if not evidence_kind.is_empty() else &""
	return {
		"id": occurrence_id,
		"occurrence_id": occurrence_id,
		"runtime_id": id,
		"definition_id": id,
		"event_kind": event_kind,
		"issue": issue,
		"title": presentation_title,
		"description": presentation_description,
		"affected_workers": affected_worker_ids.duplicate(),
		"major": major,
		"pattern": visual_pattern,
		"started_tick": maxi(0, started_tick),
		"completion": &"active",
		"evidence_id": evidence_id,
		"evidence_kind": evidence_kind,
		"evidence_source": resolved_source,
		"evidence_reliability": evidence_reliability,
		"evidence_window_ticks": evidence_window_ticks,
	}
