extends Node
## The town's soundscape, all synthesised (see audio_mix.gd): rain, wind, night crickets, footsteps that follow the ground under you,
## a tense low drone that grows with stress and the killer's pressure, and a few one-shots (door, stamp, chime). Samples are built one
## per frame after the world appears so the first second is never spent on audio, then the engine just mixes them. The per-frame cost is
## a handful of volume updates every tenth of a second. Ambience and footsteps use the Sfx bus, the drone the Music bus.

const Mix = preload("res://scripts/world3d/audio_mix.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

var world: Node3D
var active := true
var stress := 0.0           # 0..100
var pressure := 0.0         # 0..100
var surface := "grass"
var _queue: Array = []
var _loops: Dictionary = {}       # name -> AudioStreamPlayer
var _levels: Dictionary = {}      # name -> current linear level
var _streams: Dictionary = {}     # one-shot name -> AudioStreamWAV
var _steps: Dictionary = {}       # surface -> Array of AudioStreamWAV
var _step_player: AudioStreamPlayer
var _shots: Array = []
var _shot_i := 0
var _step_acc := 0.0
var _step_n := 0
var _tick := 0.0
var _street_ys: Array = []
var ready_count := 0


func setup(w: Node3D) -> void:
	world = w
	name = "AudioKit"
	active = DisplayServer.get_name() != "headless"
	UiKit.apply_sound()
	if world != null and world.game != null:
		for s in world.game.layout.spec["streets"]:
			_street_ys.append(float(s["y"]))
	if not active:
		set_process(false)
		return
	_queue = [
		["loop", "rain", Mix.rain_loop, "Sfx"], ["loop", "wind", Mix.wind_loop, "Sfx"], ["loop", "crickets", Mix.crickets_loop, "Sfx"],
		["loop", "drone", Mix.drone_loop, "Music"], ["one", "door", Mix.door, ""], ["one", "stamp", Mix.stamp, ""],
		["one", "chime", Mix.chime.bind(true), ""], ["one", "chime_down", Mix.chime.bind(false), ""]]
	for sf in ["grass", "road", "stone", "wood"]:
		_queue.append(["steps", sf, Callable(), ""])
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = "Sfx"
	_step_player.volume_db = -11.0
	add_child(_step_player)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		p.volume_db = -6.0
		add_child(p)
		_shots.append(p)


## Build every sample right now (for tests and tools); normally they appear one a frame.
func build_all() -> void:
	while not _queue.is_empty():
		_build_next()


func _build_next() -> void:
	if _queue.is_empty():
		return
	var job: Array = _queue.pop_front()
	var kind: String = job[0]
	var nm: String = job[1]
	match kind:
		"loop":
			var p := AudioStreamPlayer.new()
			p.stream = (job[2] as Callable).call()
			p.bus = job[3]
			p.volume_db = -80.0
			add_child(p)
			p.play()
			_loops[nm] = p
			_levels[nm] = 0.0
		"one":
			_streams[nm] = (job[2] as Callable).call()
		"steps":
			var arr: Array = []
			for v in 3:
				arr.append(Mix.footstep(nm, v))
			_steps[nm] = arr
	ready_count += 1


func play(nm: String) -> void:
	if not active or not _streams.has(nm) or not UiKit.get_v("sound"):
		return
	var p: AudioStreamPlayer = _shots[_shot_i % _shots.size()]
	_shot_i += 1
	p.stream = _streams[nm]
	p.play()


## What is under your feet at a point: "wood" inside and on the lake boards, "road" and "stone" near the streets, "grass" elsewhere.
func surface_at(p: Vector3) -> String:
	if world != null and world.inside != "":
		return "wood"
	if p.z < -118.0:
		return "wood"
	var best := 99.0
	for y in _street_ys:
		best = minf(best, absf(p.z - float(y)))
	if best < 3.4:
		return "road"
	if best < 6.2:
		return "stone"
	return "grass"


func _process(delta: float) -> void:
	if not _queue.is_empty():
		_build_next()
	if world == null or world.player == null:
		return
	# footsteps: one every ~1.7 m walked
	var pl: CharacterBody3D = world.player
	var speed := Vector2(pl.velocity.x, pl.velocity.z).length()
	if world.inside == "" and not pl.frozen and speed > 0.6 and pl.visible:
		_step_acc += speed * delta
		if _step_acc >= (1.75 if not pl.running else 2.3):
			_step_acc = 0.0
			surface = surface_at(pl.global_position)
			if _steps.has(surface) and bool(UiKit.get_v("sound")):
				_step_n += 1
				var arr: Array = _steps[surface]
				_step_player.stream = arr[_step_n % arr.size()]
				_step_player.pitch_scale = 0.9 + 0.2 * fmod(float(_step_n) * 0.37, 1.0)
				_step_player.volume_db = -9.0 if pl.running else -12.0
				_step_player.play()
	else:
		_step_acc = maxf(_step_acc, 1.2)       # the first step lands soon after you start moving
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	_update_levels()


func _update_levels() -> void:
	var sky: Node3D = world.sky
	var weather: String = world.weather
	var inside: float = 0.28 if world.inside != "" else 1.0
	var targets := {
		"rain": (0.55 if weather == "rain" else 0.0) * inside,
		"wind": (0.06 + 0.2 * float(sky._w["wind"]) * (1.0 if weather != "fog" else 0.5)) * inside,
		"crickets": (0.0 if weather == "rain" else sky.night * 0.32) * inside,
		"drone": clampf(0.04 + stress / 100.0 * 0.6 + pressure / 100.0 * 0.4, 0.0, 1.0) * 0.55}
	for nm in _loops:
		var cur: float = _levels[nm]
		cur = move_toward(cur, float(targets[nm]), 0.06)
		_levels[nm] = cur
		(_loops[nm] as AudioStreamPlayer).volume_db = linear_to_db(maxf(cur, 0.0001)) - 3.0
