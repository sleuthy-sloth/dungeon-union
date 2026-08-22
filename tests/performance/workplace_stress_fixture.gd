extends RefCounted

const AGENT_COUNT := 30
const FRAMES := 900
const FRAME_DELTA := 1.0 / 60.0


func run() -> Dictionary:
	var errors: Array[String] = []
	var worker_ids: Array[StringName] = []
	for index in AGENT_COUNT:
		worker_ids.append(StringName("stress_worker_%02d" % index))
	var simulation := WorkplaceSimulation.create_from_worker_ids(20260822, worker_ids)
	var clock := SimulationClock.new()
	clock.speed = 4.0
	var emitted_ticks := 0
	var started_usec := Time.get_ticks_usec()
	for frame in FRAMES:
		var ticks := clock.advance(FRAME_DELTA)
		emitted_ticks += ticks
		for tick in ticks:
			simulation.apply_tick()
	var elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var expected_ticks := int(floor((FRAMES * FRAME_DELTA * 4.0) / SimulationClock.TICK_SECONDS))
	var snapshot: Dictionary = simulation.snapshot()
	if snapshot.workers.size() != AGENT_COUNT:
		errors.append("stress fixture expected %d agents, got %d" % [AGENT_COUNT, snapshot.workers.size()])
	if emitted_ticks != expected_ticks or snapshot.tick != expected_ticks:
		errors.append("simulation backlog: expected %d ticks, emitted %d, applied %d" % [expected_ticks, emitted_ticks, snapshot.tick])
	if clock.accumulator >= SimulationClock.TICK_SECONDS:
		errors.append("simulation backlog left %.6f seconds in the fixed clock" % clock.accumulator)
	return {
		"agents": snapshot.workers.size(),
		"ticks": snapshot.tick,
		"elapsed_msec": elapsed_msec,
		"backlog": clock.accumulator,
		"errors": errors,
	}
