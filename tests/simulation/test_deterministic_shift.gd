extends RefCounted

static func run(t: TestCase) -> void:
	_same_seed_produces_same_shift(t)
	_equivalent_render_cadences_produce_same_snapshot(t)
	_equivalent_one_and_four_times_clock_feeds_produce_same_snapshot(t)
	_pause_preserves_partial_remainder_and_ignores_elapsed_time(t)
	_named_random_streams_are_independent(t)


static func _same_seed_produces_same_shift(t: TestCase) -> void:
	var a := WorkplaceSimulation.create_fixture(9917)
	var b := WorkplaceSimulation.create_fixture(9917)
	for index in 120:
		a.apply_tick()
		b.apply_tick()
	t.equal(a.snapshot(), b.snapshot(), "same seed produces same shift")


static func _equivalent_one_and_four_times_clock_feeds_produce_same_snapshot(t: TestCase) -> void:
	var normal := WorkplaceSimulation.create_fixture(9917)
	var accelerated := WorkplaceSimulation.create_fixture(9917)
	var normal_clock := SimulationClock.new()
	var accelerated_clock := SimulationClock.new()
	accelerated_clock.speed = 4.0

	for frame in 120:
		for tick in normal_clock.advance(0.25):
			normal.apply_tick()
		for tick in accelerated_clock.advance(0.0625):
			accelerated.apply_tick()

	t.equal(
		normal.snapshot(),
		accelerated.snapshot(),
		"equivalent logical ticks produce equal snapshots at one and four times speed"
	)


static func _equivalent_render_cadences_produce_same_snapshot(t: TestCase) -> void:
	var quarter_second_frame := WorkplaceSimulation.create_fixture(9917)
	var sixty_fps_frames := WorkplaceSimulation.create_fixture(9917)
	var quarter_second_clock := SimulationClock.new()
	var sixty_fps_clock := SimulationClock.new()

	for tick in quarter_second_clock.advance(0.25):
		quarter_second_frame.apply_tick()
	for frame in 15:
		for tick in sixty_fps_clock.advance(1.0 / 60.0):
			sixty_fps_frames.apply_tick()

	t.equal(
		quarter_second_frame.snapshot(),
		sixty_fps_frames.snapshot(),
		"one 0.25-second frame matches fifteen one-sixtieth-second frames"
	)


static func _pause_preserves_partial_remainder_and_ignores_elapsed_time(t: TestCase) -> void:
	var clock := SimulationClock.new()
	for frame in 14:
		t.equal(clock.advance(1.0 / 60.0), 0, "partial sixty FPS frame emits no tick")
	var partial_remainder := clock.accumulator
	clock.paused = true

	t.equal(clock.advance(999.0), 0, "paused time emits no ticks")
	t.equal(clock.accumulator, partial_remainder, "paused time preserves the partial remainder")

	clock.paused = false
	t.equal(
		clock.advance(1.0 / 60.0),
		1,
		"resuming with the final sixty FPS frame emits the deferred fixed tick"
	)


static func _named_random_streams_are_independent(t: TestCase) -> void:
	var baseline := RandomStreams.new(9917)
	var interleaved := RandomStreams.new(9917)
	var expected := baseline.draw(&"worker_load", 100)

	interleaved.draw(&"cosmetic", 100)
	var actual := interleaved.draw(&"worker_load", 100)

	t.equal(actual, expected, "drawing another named stream does not change a worker stream")
