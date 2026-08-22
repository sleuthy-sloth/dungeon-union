class_name RandomStreams
extends RefCounted

var master_seed: int
var streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(seed: int) -> void:
	master_seed = seed


func draw(stream: StringName, upper_bound: int) -> int:
	assert(upper_bound > 0, "upper_bound must be positive")
	return _stream_for(stream).randi_range(0, upper_bound - 1)


func _stream_for(stream: StringName) -> RandomNumberGenerator:
	if not streams.has(stream):
		var generator := RandomNumberGenerator.new()
		generator.seed = master_seed + hash(stream)
		streams[stream] = generator
	return streams[stream]
