class_name WorkplaceDirector
extends RefCounted

const EventDefinitionScript = preload("res://src/events/event_definition.gd")
const EventEngineScript = preload("res://src/events/event_engine.gd")
const RandomStreamsScript = preload("res://src/simulation/random_streams.gd")

const MAJOR_EVENT_GAP_TICKS := 180
const FAMILY_REPEAT_WORKDAYS := 2

var _event_engine: EventEngineScript
var _random_streams: RandomStreamsScript
var _snapshot: Dictionary = {}
var _last_major_tick := -MAJOR_EVENT_GAP_TICKS
var _family_last_workday: Dictionary[StringName, int] = {}
var _current_workday := 1
var _active_major_event: StringName = &""
var _active_event_ids: Dictionary[StringName, bool] = {}


func _init(events: Array, seed: int, snapshot: Dictionary = {}) -> void:
	_event_engine = EventEngineScript.new(events)
	_random_streams = RandomStreamsScript.new(seed)
	_snapshot = snapshot.duplicate(true)


static func fixture(seed: int) -> WorkplaceDirector:
	var events: Array[EventDefinitionScript] = []
	for family in [
		&"cave_in_risk",
		&"lantern_fumes",
		&"unpaid_maintenance",
		&"adventurer_alarm",
		&"foreman_intimidation",
		&"spontaneous_mutual_aid",
	]:
		var event := EventDefinitionScript.new()
		event.id = family
		event.family = family
		events.append(event)
	return load("res://src/events/workplace_director.gd").new(events, seed)


func update_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)


func set_workday(workday: int) -> void:
	_current_workday = maxi(1, workday)


func eligible_events(tick: int) -> Array[EventDefinitionScript]:
	var current_snapshot := _snapshot.duplicate(true)
	current_snapshot["tick"] = tick
	var matches: Array[EventDefinitionScript] = []
	for event in _event_engine.eligible(current_snapshot):
		if _active_event_ids.has(event.id):
			continue
		if event.major and not _active_major_event.is_empty():
			continue
		if event.major and tick - _last_major_tick < MAJOR_EVENT_GAP_TICKS:
			continue
		if _family_was_recent(event.family):
			continue
		matches.append(event)
	return matches


func choose_next(tick: int) -> EventDefinitionScript:
	var matches := eligible_events(tick)
	if matches.is_empty():
		return null
	return matches[_random_streams.draw(&"workplace_events", matches.size())]


func choose_and_start(tick: int) -> EventDefinitionScript:
	var event := choose_next(tick)
	if event == null:
		return null
	_family_last_workday[event.family] = _current_workday
	_active_event_ids[event.id] = true
	if event.major:
		_last_major_tick = tick
		_active_major_event = event.id
	return event


func complete_event(event_id: StringName) -> bool:
	if not _active_event_ids.has(event_id):
		return false
	_active_event_ids.erase(event_id)
	if _active_major_event == event_id:
		_active_major_event = &""
	return true


func durable_snapshot() -> Dictionary:
	var active_ids: Array[StringName] = _active_event_ids.keys()
	active_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return {
		"last_major_tick": _last_major_tick,
		"family_last_workday": _family_last_workday.duplicate(true),
		"current_workday": _current_workday,
		"active_major_event": _active_major_event,
		"active_event_ids": active_ids,
		"random_streams": _random_streams.durable_snapshot(),
	}


func restore_progress(view: Dictionary) -> void:
	_last_major_tick = int(view.get("last_major_tick", -MAJOR_EVENT_GAP_TICKS))
	_family_last_workday.clear()
	for family in view.get("family_last_workday", {}):
		_family_last_workday[StringName(family)] = maxi(1, int(view.family_last_workday[family]))
	_current_workday = maxi(1, int(view.get("current_workday", 1)))
	_active_major_event = StringName(view.get("active_major_event", &""))
	_active_event_ids.clear()
	for event_id in view.get("active_event_ids", []):
		_active_event_ids[StringName(event_id)] = true
	if view.has("random_streams"):
		_random_streams = RandomStreamsScript.restore(_random_streams.master_seed, view.random_streams)


func _family_was_recent(family: StringName) -> bool:
	if not _family_last_workday.has(family):
		return false
	return _current_workday - _family_last_workday[family] < FAMILY_REPEAT_WORKDAYS
