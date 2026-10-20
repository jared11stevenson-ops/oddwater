extends Node3D
## The 3D town as a game: you walk about as the host, the town lives around you in real time, and time passes while you do.
## This node owns the sim (TownGame), the 3D world, the sky, the residents' bodies and your body, and turns walking up to a door
## or a person into the things the sim already knows how to do (enter and act, talk). It also owns the weather effects that follow
## you about (rain, splashes, leaves, fireflies, birds), the pooled night lights, the vignette and the quality knob.

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
const Merge = preload("res://scripts/world3d/merger.gd")
const Scenery = preload("res://scripts/world3d/scenery.gd")
const DRIFT = preload("res://shaders/drift3d.gdshader")
const VIGNETTE = preload("res://shaders/vignette.gdshader")
const TAPE = preload("res://shaders/tape3d.gdshader")
const SIREN = preload("res://shaders/siren3d.gdshader")

## Quality presets: 3D render scale, shadow reach (m), rain particles, whether glow and MSAA are on, how far the grass shows.
const QUALITY := [
	{"name": "low", "scale": 0.67, "shadow": 40.0, "rain": 500, "glow": false, "msaa": 0, "lights": 2},
	{"name": "medium", "scale": 0.85, "shadow": 65.0, "rain": 800, "glow": true, "msaa": 0, "lights": 3},
	{"name": "high", "scale": 1.0, "shadow": 90.0, "rain": 1100, "glow": true, "msaa": 1, "lights": 4}]

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
var splash: GPUParticles3D
var weather_override := ""        # "" = follow the sim's weather; otherwise "clear", "cloudy", "rain" or "fog"
var quality := 2
var weather := "clear"
var vignette_rect: ColorRect
var lamp_lights: Array = []
var leaves: MultiMeshInstance3D
var fireflies: MultiMeshInstance3D
var birds: MultiMeshInstance3D
var _vig_mat: ShaderMaterial
var _leaf_mat: ShaderMaterial
var _fly_mat: ShaderMaterial
var _bird_mat: ShaderMaterial
var _prompt_timer := 0.0
var _light_timer := 0.0
var _lamp_timer := 0.0
var _weather := ""
var _door_ids: Array = []
var _door_fronts: PackedVector3Array = PackedVector3Array()
var _last_scan := Vector3(1e9, 0, 0)


func start(seed_value: int = 1961, loaded: RefCounted = null) -> void:
	start_game(loaded if loaded != null else TownGame.new(seed_value))


## Start the world around any game model (a town sim, or the detective game).
func start_game(the_game: RefCounted) -> void:
	game = the_game
	builder = Builder.new()
	add_child(builder)
	builder.build(game.layout)
	_door_ids = builder.doors.keys()
	for id in _door_ids:
		_door_fronts.append((builder.doors[id]["front"] as Vector3))
	sky = SkyCycle.new()
	add_child(sky)
	sky.build()
	for m in builder.sky_materials():
		sky.register_material(m)
	npcs = NpcManager.new()
	add_child(npcs)
	npcs.tick_seconds = tick_seconds
	npcs.setup(game.sim, builder, game.layout.spec)
	player = PlayerRig.new()
	add_child(player)
	_build_rain()
	_build_ambient()
	_build_lamp_lights()
	_build_vignette()
	set_quality(1 if OS.has_feature("mobile") else 2)
	place_host(true)
	refresh_markers()


func _exit_tree() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().scaling_3d_scale = 1.0
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED


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


## Force a weather (for a screenshot, a test, or a mood). "" hands control back to the sim.
func set_weather_override(w: String) -> void:
	weather_override = w
	_apply_weather()


func _apply_weather() -> void:
	_weather = weather_override if weather_override != "" else game.sim.weather_today()
	weather = _weather
	sky.set_weather(_weather)
	_update_weather_fx()


func _update_weather_fx() -> void:
	var raining := _weather == "rain"
	if rain != null:
		rain.emitting = raining
	if splash != null:
		splash.emitting = raining
	if _leaf_mat != null:
		_leaf_mat.set_shader_parameter("amount", 0.0 if raining or _weather == "fog" else 1.0)
	if vignette_rect != null:
		_vig_mat.set_shader_parameter("strength", sky.vignette)


func _update_light() -> void:
	sky.set_hour(hour())
	if _fly_mat != null:
		_fly_mat.set_shader_parameter("amount", sky.night * (0.0 if _weather in ["rain", "fog"] else 1.0))
		_bird_mat.set_shader_parameter("amount", sky.daylight * (1.0 if _weather in ["clear", "cloudy"] else 0.0))
		_leaf_mat.set_shader_parameter("amount", sky.daylight * (0.0 if _weather in ["rain", "fog"] else 1.0))
		_vig_mat.set_shader_parameter("strength", sky.vignette)


# ------------------------------------------------------------------ weather effects that follow you
func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1100
	rain.lifetime = 0.62
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-24, -4, -24), Vector3(48, 22, 48))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 0.5, 22)
	pm.direction = Vector3(0.14, -1.0, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 25.0
	pm.initial_velocity_max = 31.0
	pm.gravity = Vector3(0, -6, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.95)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.9, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.fixed_size = false
	q.material = mat
	rain.draw_pass_1 = q
	rain.emitting = false
	add_child(rain)
	# splashes where the drops land: rings that grow and fade on the ground around you
	splash = GPUParticles3D.new()
	splash.name = "Splashes"
	splash.amount = 260
	splash.lifetime = 0.45
	splash.local_coords = false
	splash.visibility_aabb = AABB(Vector3(-24, -1, -24), Vector3(48, 3, 48))
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = Vector3(20, 0.01, 20)
	sm.gravity = Vector3.ZERO
	sm.initial_velocity_min = 0.0
	sm.initial_velocity_max = 0.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.15))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	sm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	sm.color_ramp = rt
	splash.process_material = sm
	var rm := QuadMesh.new()
	rm.size = Vector2(0.55, 0.55)
	rm.orientation = PlaneMesh.FACE_Y
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.vertex_color_use_as_albedo = true
	rmat.albedo_color = Color(0.85, 0.92, 1.0, 0.7)
	var ring := Gradient.new()
	ring.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
	ring.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = ring
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	rmat.albedo_texture = gt
	rm.material = rmat
	splash.draw_pass_1 = rm
	splash.emitting = false
	add_child(splash)


## Leaves, fireflies and birds: three tiny MultiMeshes whose motion is done entirely in vertex shaders.
func _build_ambient() -> void:
	var leaf_mesh := QuadMesh.new()
	leaf_mesh.size = Vector2(0.2, 0.14)
	_leaf_mat = _drift_mat(0, Color("c9803a"))
	leaves = _drift_mm(leaf_mesh, _leaf_mat, 56, "Leaves")
	var fly_mesh := QuadMesh.new()
	fly_mesh.size = Vector2(0.22, 0.22)
	_fly_mat = _drift_mat(1, Color("e8ff8a"))
	_fly_mat.set_shader_parameter("amount", 0.0)
	fireflies = _drift_mm(fly_mesh, _fly_mat, 60, "Fireflies")
	var bm := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0.1), Vector3(-1.0, 0.0, -0.2), Vector3(0, 0, -0.25), Vector3(0, 0, 0.1), Vector3(0, 0, -0.25), Vector3(1.0, 0.0, -0.2)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.5, 0), Vector2(0, 1), Vector2(0.5, 1), Vector2(0.5, 0), Vector2(0.5, 1), Vector2(1, 1)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	bm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_bird_mat = _drift_mat(2, Color("111116"))
	_bird_mat.set_shader_parameter("time_scale", 1.0)
	birds = _drift_mm(bm, _bird_mat, 10, "Birds")
	for mm in [leaves, fireflies, birds]:
		(mm as MultiMeshInstance3D).custom_aabb = AABB(Vector3(-200, -40, -200), Vector3(400, 120, 400))
	_bird_mat.set_shader_parameter("amount", 1.0)


func _drift_mat(mode: int, col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = DRIFT
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("tint", col)
	return m


func _drift_mm(mesh: Mesh, mat: ShaderMaterial, n: int, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = node_name
	add_child(mi)
	return mi


## Four real lights, pooled onto the lamps nearest you at night, fading with distance so they never pop.
func _build_lamp_lights() -> void:
	for i in 4:
		var l := OmniLight3D.new()
		l.omni_range = 17.0
		l.omni_attenuation = 1.5
		l.light_color = Color(1.0, 0.76, 0.42)
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.light_specular = 0.2
		l.visible = false
		l.name = "LampLight%d" % i
		add_child(l)
		lamp_lights.append(l)


func _update_lamp_lights() -> void:
	var night: float = sky.night
	var p: Vector3 = player.global_position
	var active := night > 0.05
	var count: int = int(QUALITY[quality]["lights"])
	var best: Array = []        # [dist2, index]
	if active:
		var lp: PackedVector3Array = builder.lamp_positions
		for i in lp.size():
			var d2 := p.distance_squared_to(lp[i])
			if d2 > 1600.0:
				continue
			best.append([d2, i])
		best.sort_custom(func(a, b): return a[0] < b[0])
	for i in lamp_lights.size():
		var l: OmniLight3D = lamp_lights[i]
		if i < count and i < best.size():
			var pos: Vector3 = builder.lamp_positions[best[i][1]] - Vector3(0, 0.3, 0)
			var d: float = sqrt(best[i][0])
			l.global_position = pos
			l.light_energy = 2.4 * night * (1.0 - smoothstep(9.0, 24.0, d)) * (0.7 if _weather == "rain" else 1.0)
			l.visible = l.light_energy > 0.02
		else:
			l.light_energy = 0.0
			l.visible = false


func _build_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -2
	cl.name = "Grade"
	add_child(cl)
	vignette_rect = ColorRect.new()
	vignette_rect.color = Color.WHITE
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = VIGNETTE
	vignette_rect.material = _vig_mat
	cl.add_child(vignette_rect)


## The quality knob: 0 low, 1 medium, 2 high. Scales the 3D render, the shadows and the weather particles.
func set_quality(q: Variant) -> void:
	var qi := 1
	if q is String:
		qi = {"low": 0, "med": 1, "medium": 1, "high": 2}.get(String(q), 1)
	else:
		qi = int(q)
	quality = clampi(qi, 0, QUALITY.size() - 1)
	var cfg: Dictionary = QUALITY[quality]
	if is_inside_tree() and get_viewport() != null:
		get_viewport().scaling_3d_scale = float(cfg["scale"])
		get_viewport().msaa_3d = Viewport.MSAA_2X if int(cfg["msaa"]) > 0 else Viewport.MSAA_DISABLED
	if sky != null:
		sky.set_shadow_distance(float(cfg["shadow"]))
		sky.env.glow_enabled = bool(cfg["glow"]) and sky.night > 0.35
	if rain != null:
		rain.amount = int(cfg["rain"])
		splash.amount = int(int(cfg["rain"]) * 0.25)


func _process(delta: float) -> void:
	if game == null:
		return
	var p: Vector3 = player.global_position
	npcs.focus = p
	if rain != null:
		rain.global_position = p + Vector3(0, 14, 0)
		splash.global_position = Vector3(p.x, 0.06, p.z)
	for mm in [leaves, fireflies, birds]:
		if mm != null:
			(mm as Node3D).global_position = Vector3(p.x, 0.0, p.z)
	if _beam_mat != null and _marker != null:
		var d: Dictionary = builder.doors.get(game.case["scene"], {})
		if not d.is_empty():
			var dist := p.distance_to(d["front"])
			_beam_mat.albedo_color.a = clampf((dist - 10.0) / 30.0, 0.0, 1.0) * 0.24      # the beam fades when you are standing in it
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.25
		_update_light()
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.35
		_update_lamp_lights()
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
	var best_d := 196.0
	for i in _door_fronts.size():
		var dd := _door_fronts[i].distance_squared_to(p)
		if dd < best_d:
			best_d = dd
			best = _door_ids[i]
	return best


# ------------------------------------------------------------------ interacting
func _refresh_prompt() -> void:
	var np: Dictionary = {}
	if inside == "" and game.phase == "day" and not paused:
		var p := player.global_position
		var people: Array = npcs.nearby(p, 3.0)
		if people.is_empty():
			if not game.near.is_empty():
				game.near = []
		else:
			game.near = people.map(func(x): return x["id"])
		var best_d := 99.0
		if not people.is_empty():
			var n: Dictionary = people[0]
			np = {"kind": "talk", "id": n["id"], "label": "Talk to %s" % String(game.sim.people[n["id"]].display).split(" ")[0]}
			best_d = n["dist"]
		var lim := 3.6 * 3.6
		for i in _door_fronts.size():
			var dd := _door_fronts[i].distance_squared_to(p)
			if dd < lim:
				var dist := sqrt(dd)
				if dist < best_d + 0.8:
					var id: String = _door_ids[i]
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


# ------------------------------------------------------------------ the case on the map
var _marker: Node3D
var _beam_mat: StandardMaterial3D


## A crime scene: a sagging line of tape on two stanchions, a chalk outline on the path, yellow evidence markers, a patrol car at the
## kerb with its light bar going, and a beam of light you can see from across the town.
func refresh_markers() -> void:
	if _marker != null:
		_marker.queue_free()
		_marker = null
	_beam_mat = null
	if not game.get("case") or game.case.is_empty() or game.solved():
		return
	var d: Dictionary = builder.doors.get(game.case["scene"], {})
	if d.is_empty():
		return
	_marker = Node3D.new()
	_marker.name = "CrimeScene"
	add_child(_marker)
	var f: Vector3 = d["front"]
	var face: float = float(d["face"])
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("14121c")
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f4f1e8")
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	# stanchions
	var span := 2.6
	var tape_z := f.z + face * 0.5
	for sx in [-span, span]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025; cm.bottom_radius = 0.03; cm.height = 1.35; cm.radial_segments = 6; cm.rings = 1
		post.mesh = cm
		post.material_override = black
		post.position = Vector3(f.x + sx, 0.675, tape_z)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(post)
		var foot := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.16; fm.bottom_radius = 0.2; fm.height = 0.08; fm.radial_segments = 8; fm.rings = 1
		foot.mesh = fm
		foot.material_override = black
		foot.position = Vector3(f.x + sx, 0.04, tape_z)
		foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(foot)
	# the tape: two sagging strands, plus one running back to the door frame on each side
	var tape := MeshInstance3D.new()
	tape.mesh = _tape_mesh([
		[Vector3(f.x - span, 1.25, tape_z), Vector3(f.x + span, 1.25, tape_z), 0.22],
		[Vector3(f.x - span, 0.95, tape_z), Vector3(f.x + span, 0.95, tape_z), 0.3],
		[Vector3(f.x - span, 1.25, tape_z), Vector3(f.x - 0.8, 1.1, f.z - face * 1.2), 0.08],
		[Vector3(f.x + span, 1.25, tape_z), Vector3(f.x + 0.8, 1.1, f.z - face * 1.2), 0.08]])
	var tm := ShaderMaterial.new()
	tm.shader = TAPE
	tape.material_override = tm
	tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tape.name = "Tape"
	_marker.add_child(tape)
	# chalk outline on the path in front of the door, lying along it with the head toward the street
	var chalk := MeshInstance3D.new()
	chalk.mesh = _chalk_mesh()
	chalk.material_override = white
	chalk.position = Vector3(f.x + 0.2, 0.125, f.z - face * 1.9)
	chalk.rotation.y = 0.0 if face > 0.0 else PI
	chalk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chalk.name = "Chalk"
	_marker.add_child(chalk)
	# evidence markers: little yellow tents
	var tentm := Merge.new()
	tentm.cell = 1.0e9
	var spots := [Vector3(0.9, 0, -1.2), Vector3(-0.8, 0, -2.6), Vector3(0.6, 0, -3.1), Vector3(-1.1, 0, -0.4)]
	for sp in spots:
		var ws: Vector3 = Vector3(f.x, 0.125, f.z) + Vector3(sp.x, 0, sp.z * face)
		tentm.add("prism", Transform3D(Basis(Vector3.UP, 0.4 * sp.x) * Basis.from_scale(Vector3(0.2, 0.28, 0.12)), ws + Vector3(0, 0.14, 0)), Color("f5c518"))
		tentm.box(ws + Vector3(0, 0.02, 0), Vector3(0.2, 0.03, 0.14), Color("14121c"))
	var tents := MeshInstance3D.new()
	tents.mesh = tentm.to_mesh()
	tents.material_override = builder.solid_mat
	tents.name = "EvidenceMarkers"
	_marker.add_child(tents)
	# a patrol car at the kerb
	var carm := Merge.new()
	carm.cell = 1.0e9
	var sgn := 1.0 if face < 0.0 else -1.0
	var car_pos := Vector3(f.x - 7.5, 0.0, (d["door"] as Vector3).z - sgn * 3.8)
	Scenery.car(carm, car_pos, PI / 2.0, Color("3a4252"), true)
	var car := MeshInstance3D.new()
	car.mesh = carm.to_mesh()
	car.material_override = builder.solid_mat
	car.name = "PatrolCar"
	_marker.add_child(car)
	for k in 2:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.14, 0.34)
		bar.mesh = bm
		var sm := ShaderMaterial.new()
		sm.shader = SIREN
		sm.set_shader_parameter("side", float(k))
		bar.material_override = sm
		bar.position = car_pos + Vector3(0, 1.62, (-0.4 if k == 0 else 0.4))
		_marker.add_child(bar)
	var cb := StaticBody3D.new()
	var cc := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(4.3, 1.6, 1.8)
	cc.shape = cbs
	cb.add_child(cc)
	cb.position = car_pos + Vector3(0, 0.8, 0)
	_marker.add_child(cb)
	# the beam
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.6; bc.bottom_radius = 0.6; bc.height = 60.0; bc.radial_segments = 8; bc.rings = 1
	beam.mesh = bc
	var bm2 := StandardMaterial3D.new()
	bm2.albedo_color = Color(1.0, 0.75, 0.2, 0.22)
	bm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm2.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm2
	_beam_mat = bm2
	beam.position = f + Vector3(0, 30.0, face * -1.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam)


## A ribbon mesh for each strand [from, to, sag]: a catenary-ish curve, 0.07 m tall, UV.x along it for the stripes.
func _tape_mesh(strands: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var n := 18
	for s in strands:
		var a: Vector3 = s[0]
		var c: Vector3 = s[1]
		var sag: float = s[2]
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		for i in n + 1:
			var t := float(i) / float(n)
			var p := a.lerp(c, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
			var top := p + Vector3(0, 0.035, 0)
			var bot := p - Vector3(0, 0.035, 0)
			if i > 0:
				var u0 := float(i - 1) / float(n)
				v.append_array(PackedVector3Array([prev_bot, prev_top, top, prev_bot, top, bot]))
				uv.append_array(PackedVector2Array([Vector2(u0, 0), Vector2(u0, 1), Vector2(t, 1), Vector2(u0, 0), Vector2(t, 1), Vector2(t, 0)]))
			prev_top = top
			prev_bot = bot
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## A body outline in chalk, drawn as thin ribbons lying flat: head, torso, arms and legs, in a slightly twisted pose.
func _chalk_mesh() -> ArrayMesh:
	var loops: Array = []
	var head: Array = []
	for i in 14:
		var a := TAU * float(i) / 14.0
		head.append(Vector2(cos(a) * 0.12, sin(a) * 0.14 - 0.78))
	loops.append(head)
	loops.append([Vector2(-0.1, -0.64), Vector2(-0.3, -0.58), Vector2(-0.34, -0.1), Vector2(-0.26, 0.28), Vector2(0.26, 0.28), Vector2(0.32, -0.1), Vector2(0.3, -0.58), Vector2(0.1, -0.64)])
	loops.append([Vector2(-0.3, -0.58), Vector2(-0.68, -0.42), Vector2(-0.92, -0.18), Vector2(-0.86, -0.1), Vector2(-0.6, -0.3), Vector2(-0.34, -0.36)])
	loops.append([Vector2(0.3, -0.58), Vector2(0.62, -0.7), Vector2(0.82, -0.92), Vector2(0.9, -0.86), Vector2(0.72, -0.58), Vector2(0.34, -0.38)])
	loops.append([Vector2(-0.26, 0.28), Vector2(-0.34, 0.8), Vector2(-0.42, 1.2), Vector2(-0.28, 1.22), Vector2(-0.12, 0.8), Vector2(-0.02, 0.28)])
	loops.append([Vector2(0.02, 0.28), Vector2(0.18, 0.8), Vector2(0.4, 1.12), Vector2(0.52, 1.04), Vector2(0.34, 0.7), Vector2(0.26, 0.28)])
	var v := PackedVector3Array()
	var w := 0.035
	for lp in loops:
		var pts: Array = lp
		for i in pts.size():
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[(i + 1) % pts.size()]
			var dir := (p1 - p0).normalized()
			var nrm := Vector2(-dir.y, dir.x) * w
			var a := Vector3(p0.x - nrm.x, 0, p0.y - nrm.y)
			var b := Vector3(p0.x + nrm.x, 0, p0.y + nrm.y)
			var c := Vector3(p1.x + nrm.x, 0, p1.y + nrm.y)
			var dd := Vector3(p1.x - nrm.x, 0, p1.y - nrm.y)
			v.append_array(PackedVector3Array([a, c, b, a, dd, c]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
