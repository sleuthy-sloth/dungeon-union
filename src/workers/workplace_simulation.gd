class_name WorkplaceSimulation
extends RefCounted

const FIXTURE_WORKER_IDS: Array[StringName] = [
	&"nib", &"brakka", &"clatter", &"drusk", &"ember", &"fizz",
	&"grib", &"hush", &"ivor", &"jink", &"kora", &"lute",
]

var worker_states: Dictionary[StringName, WorkerState] = {}
var _random_streams: RandomStreams
var _tick := 0


func _init(seed: int) -> void:
	_random_streams = RandomStreams.new(seed)


static func create_fixture(seed: int) -> WorkplaceSimulation:
	var simulation := WorkplaceSimulation.new(seed)
	for worker_id in FIXTURE_WORKER_IDS:
		simulation.worker_states[worker_id] = WorkerState.new(worker_id)
	return simulation


func apply_tick() -> Array[Dictionary]:
	_tick += 1
	var changes: Array[Dictionary] = []
	for worker_id in _sorted_worker_ids():
		var worker := worker_states[worker_id]
		if worker.employment_state != &"active":
			continue
		var load := _random_streams.draw(&"worker_load", 3)
		worker.apply_work_tick(load)
		changes.append({
			"tick": _tick,
			"worker_id": worker_id,
			"load": load,
		})
	return changes


func snapshot() -> Dictionary:
	var workers: Array[Dictionary] = []
	for worker_id in _sorted_worker_ids():
		workers.append(worker_states[worker_id].snapshot())
	return {
		"tick": _tick,
		"workers": workers,
	}


func _sorted_worker_ids() -> Array[StringName]:
	var worker_ids: Array[StringName] = worker_states.keys()
	worker_ids.sort()
	return worker_ids
