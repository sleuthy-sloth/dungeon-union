class_name SimulationClock
extends RefCounted

const TICK_SECONDS := 0.25

var speed := 1.0
var paused := false
var accumulator := 0.0


func advance(real_delta: float) -> int:
	if paused:
		return 0
	accumulator += real_delta * speed
	var ticks := int(accumulator / TICK_SECONDS)
	accumulator -= ticks * TICK_SECONDS
	return ticks
