class_name RandomStreams
extends RefCounted

var master_seed: int
var streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(seed: int) -> void:
	master_seed = seed


func draw(stream: StringName, upper_bound: int) -> int:
	assert(upper_bound > 0, "upper_bound must be positive")
	return _stream_for(stream).randi_range(0, upper_bound - 1)


func durable_snapshot() -> Dictionary:
	var states := {}
	var names: Array[StringName] = streams.keys()
	names.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for stream_name in names:
		states[stream_name] = streams[stream_name].state
	return {"master_seed": master_seed, "stream_states": states}


static func restore(seed: int, view: Dictionary) -> RandomStreams:
	var restored := RandomStreams.new(int(view.get("master_seed", seed)))
	var states: Dictionary = view.get("stream_states", {})
	for stream_name in states:
		var generator := RandomNumberGenerator.new()
		generator.seed = restored.master_seed + hash(StringName(stream_name))
		generator.state = int(states[stream_name])
		restored.streams[StringName(stream_name)] = generator
	return restored


func _stream_for(stream: StringName) -> RandomNumberGenerator:
	if not streams.has(stream):
		var generator := RandomNumberGenerator.new()
		generator.seed = master_seed + hash(stream)
		streams[stream] = generator
	return streams[stream]
