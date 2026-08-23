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
	return create_from_worker_ids(seed, FIXTURE_WORKER_IDS)


static func create_from_worker_ids(seed: int, worker_ids: Array[StringName]) -> WorkplaceSimulation:
	var simulation := WorkplaceSimulation.new(seed)
	for worker_id in worker_ids:
		if worker_id.is_empty() or simulation.worker_states.has(worker_id):
			continue
		simulation.worker_states[worker_id] = WorkerState.new(worker_id)
	return simulation


static func create_from_definitions(seed: int, definitions: Array[WorkerDefinition]) -> WorkplaceSimulation:
	var simulation := WorkplaceSimulation.new(seed)
	for definition in definitions:
		if definition == null or definition.id.is_empty() or simulation.worker_states.has(definition.id):
			continue
		simulation.worker_states[definition.id] = WorkerState.from_definition(definition)
	return simulation


static func restore(seed: int, state: Dictionary) -> WorkplaceSimulation:
	var simulation := WorkplaceSimulation.new(seed)
	var restored_tick := maxi(0, int(state.get("tick", 0)))
	if state.has("random_streams"):
		simulation._random_streams = RandomStreams.restore(seed, state.random_streams)
	else:
		# Backward-compatible reconstruction for saves from before stream state was durable.
		for tick in restored_tick:
			for raw_worker in state.get("workers", []):
				if StringName(raw_worker.get("employment_state", &"active")) == &"active":
					simulation._random_streams.draw(&"worker_load", 3)
	for raw_worker in state.get("workers", []):
		var worker := WorkerState.from_view(raw_worker)
		if not worker.id.is_empty():
			simulation.worker_states[worker.id] = worker
	simulation._tick = restored_tick
	return simulation


func durable_snapshot() -> Dictionary:
	var state := snapshot()
	state["random_streams"] = _random_streams.durable_snapshot()
	return state


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
