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


func set_active_major_event(event_id: StringName) -> void:
	if _active_major_event.is_empty() or _active_major_event == event_id:
		_active_major_event = event_id


func clear_active_major_event(event_id: StringName) -> void:
	if _active_major_event == event_id:
		_active_major_event = &""


func record_major_event(family: StringName, tick: int) -> void:
	_last_major_tick = tick
	_family_last_workday[family] = _current_workday


func eligible_events(tick: int) -> Array[EventDefinitionScript]:
	var current_snapshot := _snapshot.duplicate(true)
	current_snapshot["tick"] = tick
	var matches: Array[EventDefinitionScript] = []
	for event in _event_engine.eligible(current_snapshot):
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


func _family_was_recent(family: StringName) -> bool:
	if not _family_last_workday.has(family):
		return false
	return _current_workday - _family_last_workday[family] < FAMILY_REPEAT_WORKDAYS
