extends RefCounted
## Steady-hand drilling: hold the cursor inside a drifting zone. Chat is a distraction that widens
## the drift. Fully deterministic given the seed; cozy mode has a generous zone.

var t := 0.0
var in_zone_time := 0.0
var seed_phase := 0.0
var zone_radius := 0.18        # cozy default (normalised units)
var distraction := 0.0         # 0..1


func _init(phase: float = 0.0, radius: float = 0.18) -> void:
	seed_phase = phase
	zone_radius = radius


## Where the zone centre is at time `time` (normalised -1..1 on both axes).
func target(time: float) -> Vector2:
	var amp := 0.35 + 0.35 * distraction
	return Vector2(amp * sin(time * 0.9 + seed_phase) + 0.1 * sin(time * 2.3), amp * 0.7 * cos(time * 0.7 + seed_phase * 1.3))


func step(dt: float, player: Vector2) -> bool:
	t += dt
	var inside := player.distance_to(target(t)) <= zone_radius
	if inside:
		in_zone_time += dt
	return inside


func score() -> float:
	return clampf(in_zone_time / maxf(t, 0.0001), 0.0, 1.0)


## Applause stars 0..3 (cosmetic reward only, never gates a Seal).
func stars() -> int:
	var s := score()
	return 3 if s >= 0.85 else (2 if s >= 0.6 else (1 if s >= 0.3 else 0))
