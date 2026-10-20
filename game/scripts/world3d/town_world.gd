extends Node3D
## The 3D town as a game: you walk about as the host, the town lives around you in real time, and time passes while you do.
## This node owns the sim (TownGame), the 3D world, the sky, the residents' bodies and your body, and turns walking up to a door
## or a person into the things the sim already knows how to do (enter and act, talk).

signal prompt_changed(prompt: Dictionary)
signal entered(lot: String)
signal left
signal ticked
signal day_ended
signal talk_requested(npc: String)

const TownGame = preload("res://scripts/sim/town_game.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Builder = preload("res://scripts/world3d/town_builder.gd")
const SkyCycle = preload("res://scripts/world3d/sky_cycle.gd")
const NpcManager = preload("res://scripts/world3d/npc_manager.gd")
const PlayerRig = preload("res://scripts/world3d/player_rig.gd")

var game: RefCounted
var builder: Node3D
var sky: Node3D
var npcs: Node3D
var player: CharacterBody3D
var tick_seconds := 18.0          # real seconds per half hour of town time
var time_scale := 1.0
var acc := 0.0
var inside := ""
var paused := false               # a menu is open: the town holds its breath
var prompt: Dictionary = {}
var rain: GPUParticles3D
var _prompt_timer := 0.0
var _light_timer := 0.0
var _weather := ""


func start(seed_value: int = 1961, loaded: RefCounted = null) -> void:
	game = loaded if loaded != null else TownGame.new(seed_value)
	builder = Builder.new()
	add_child(builder)
	builder.build(game.layout)
	sky = SkyCycle.new()
	add_child(sky)
	sky.build()
	sky.register_window_material(builder.window_mat)
	sky.register_window_material(builder.water_mat)
	npcs = NpcManager.new()
	add_child(npcs)
	npcs.tick_seconds = tick_seconds
	npcs.setup(game.sim, builder, game.layout.spec)
	player = PlayerRig.new()
	add_child(player)
	_build_rain()
	place_host(true)


func hour() -> float:
	return game.sim.hour_now() + (acc / tick_seconds) * 0.5 if game.phase == "day" else 24.0


## Put you in the host's body at the host's front door. Called at the start and every dawn.
func place_host(first: bool = false) -> void:
	inside = ""
	player.visible = true
	player.frozen = false
	player.set_person(game.me())
	npcs.skip_id = game.host
	var home: Dictionary = builder.doors.get(game.me().home, {})
	if not home.is_empty():
		var f: Vector3 = home["front"]
		player.teleport(f, float(home["yaw"]))
	game.me().location = game.me().home
	npcs.focus = player.global_position
	npcs.resync(true)
	acc = 0.0
	_apply_weather()
	_update_light()


func _apply_weather() -> void:
	_weather = game.sim.weather_today()
	sky.set_weather(_weather)
	if rain != null:
		rain.emitting = _weather == "rain"


func _update_light() -> void:
	sky.set_hour(hour())


func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 1800
	rain.lifetime = 1.1
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 0.5, 28)
	pm.direction = Vector3(0.12, -1.0, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -10, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mat
	rain.draw_pass_1 = q
	rain.emitting = false
	add_child(rain)


func _process(delta: float) -> void:
	if game == null:
		return
	var p: Vector3 = player.global_position
	npcs.focus = p
	if rain != null:
		rain.global_position = p + Vector3(0, 16, 0)
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.25
		_update_light()
	# town time passes while you walk about
	if not paused and inside == "" and game.phase == "day":
		acc += delta * time_scale
		if acc >= tick_seconds:
			acc -= tick_seconds
			_tick()
	_prompt_timer -= delta
	if _prompt_timer <= 0.0:
		_prompt_timer = 0.12
		_refresh_prompt()


func _tick() -> void:
	game.realtime_tick(current_lot(), player.moved_recently > 0.0)
	npcs.resync()
	ticked.emit()
	if game.sim.day_over():
		end_of_day()


func end_of_day() -> void:
	if game.phase == "day":
		game.end_day()
	game.save()
	player.frozen = true
	day_ended.emit()


## After the UI has made time pass (an hour of work, a nap, a fast trip): everyone is somewhere new.
func time_skipped() -> void:
	npcs.resync(true)
	acc = 0.0
	_apply_weather()
	_update_light()
	if game.sim.day_over() and game.phase == "day":
		end_of_day()


func morning() -> void:
	place_host()


## The lot you are standing in or right in front of, or "".
func current_lot() -> String:
	if inside != "":
		return inside
	var p := player.global_position
	var best := ""
	var best_d := 14.0
	for id in builder.doors:
		var d: Dictionary = builder.doors[id]
		var dist: float = (d["front"] as Vector3).distance_to(p)
		if dist < best_d:
			best_d = dist
			best = id
	return best


# ------------------------------------------------------------------ interacting
func _refresh_prompt() -> void:
	var np: Dictionary = {}
	if inside == "" and game.phase == "day" and not paused:
		var p := player.global_position
		var people: Array = npcs.nearby(p, 3.0)
		game.near = people.map(func(x): return x["id"])
		var best_d := 99.0
		if not people.is_empty():
			var n: Dictionary = people[0]
			np = {"kind": "talk", "id": n["id"], "label": "Talk to %s" % String(game.sim.people[n["id"]].display).split(" ")[0]}
			best_d = n["dist"]
		for id in builder.doors:
			var d: Dictionary = builder.doors[id]
			var dist: float = (d["front"] as Vector3).distance_to(p)
			if dist < 3.6 and dist < best_d + 0.8:
				var label := "Go inside" if id == game.me().home else "Enter %s" % game.place_name(id)
				np = {"kind": "enter", "id": id, "label": label}
				best_d = dist
	else:
		game.near = []
	if np != prompt:
		prompt = np
		prompt_changed.emit(prompt)


func interact() -> void:
	if prompt.is_empty():
		return
	match prompt["kind"]:
		"talk":
			talk_requested.emit(prompt["id"])
		"enter":
			enter(prompt["id"])


func enter(lot: String) -> void:
	inside = lot
	game.me().location = lot
	player.frozen = true
	player.visible = false
	prompt = {}
	prompt_changed.emit(prompt)
	entered.emit(lot)


func leave() -> void:
	var lot := inside
	inside = ""
	player.visible = true
	player.frozen = false
	var d: Dictionary = builder.doors.get(lot, {})
	if not d.is_empty():
		player.teleport(d["front"], float(d["yaw"]))
	left.emit()


## The map's "go here": a trip that costs time (the sim's own travel cost) and puts you at the door.
func arrive_at(lot: String) -> void:
	inside = ""
	player.visible = true
	player.frozen = false
	var d: Dictionary = builder.doors.get(lot, {})
	if not d.is_empty():
		player.teleport(d["front"], float(d["yaw"]))
	time_skipped()
