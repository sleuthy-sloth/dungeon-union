extends RefCounted

static func run(t: TestCase) -> void:
	_same_seed_produces_same_shift(t)
	_equivalent_one_and_four_times_clock_feeds_produce_same_snapshot(t)
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


static func _named_random_streams_are_independent(t: TestCase) -> void:
	var baseline := RandomStreams.new(9917)
	var interleaved := RandomStreams.new(9917)
	var expected := baseline.draw(&"worker_load", 100)

	interleaved.draw(&"cosmetic", 100)
	var actual := interleaved.draw(&"worker_load", 100)

	t.equal(actual, expected, "drawing another named stream does not change a worker stream")
