extends SceneTree
## godot --headless --path game -s tests/world_polish_tests.gd : the 3D world's polish systems (baked geometry, sky, weather, people, camera).

const MainScene = preload("res://scenes/main.tscn")
const Merge = preload("res://scripts/world3d/merger.gd")
const TownGame = preload("res://scripts/detective/detective_game.gd")
var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func count_nodes(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += count_nodes(c)
	return t


func _initialize() -> void:
	# the merger bakes primitives into chunks
	var m = Merge.new()
	m.cell = 50.0
	m.box(Vector3(10, 1, 10), Vector3(2, 2, 2), Color.RED)
	m.box(Vector3(120, 1, 10), Vector3(2, 2, 2), Color.RED)
	m.upright(Vector3(-30, 1, 0), 1, 1, Color.WHITE, 0.0, 0.5)
	ok(m.cells.size() == 3 and m.verts == 36 * 2 + 6, "merger chunks by cell: %d cells, %d verts" % [m.cells.size(), m.verts])
	var holder := Node3D.new()
	var made: Array = m.build(holder, "T", StandardMaterial3D.new(), false, 100.0)
	ok(made.size() == 3 and (made[0] as MeshInstance3D).visibility_range_end == 100.0, "chunks are meshes with a draw distance")
	TownGame.delete_save()
	var main: Control = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	await process_frame
	var w: Node3D = hud.world
	var b: Node3D = w.builder
	ok(b.stats["lamps"] > 60 and b.lamp_positions.size() == b.stats["lamps"], "street lamps exist: %d" % b.stats["lamps"])
	ok(b.stats["chimneys"] > 20, "chimneys smoke: %d" % b.stats["chimneys"])
	ok(b.stats["static_tris"] > 100000, "the town is baked: %d static tris in %d chunks" % [b.stats["static_tris"], b.stats["chunks"]])
	ok(count_nodes(b) < 2500, "the builder makes few nodes: %d" % count_nodes(b))
	ok(b.doors.size() >= 120, "every lot still has a door")
	# weather: four distinct looks, and the override sticks
	var seen: Dictionary = {}
	for wx in ["clear", "cloudy", "rain", "fog"]:
		w.set_weather_override(wx)
		w._update_light()
		var sig := "%s|%s|%.4f" % [w.sky.sky_color.to_html(), str(w.sky.sun.light_energy), w.sky.env.fog_density]
		seen[sig] = true
		ok(w.weather == wx, "weather %s applied" % wx)
		ok(w.rain.emitting == (wx == "rain"), "rain only in the rain")
	ok(seen.size() == 4, "clear, cloudy, rain and fog all look different")
	w.sky.set_weather("fog")
	var fog_d: float = w.sky.env.fog_density
	w.sky.set_weather("clear")
	ok(fog_d > w.sky.env.fog_density * 5.0, "fog is thick")
	w.set_weather_override("")
	# night: moon, stars and lights come up
	w.sky.set_hour(23.0)
	ok(w.sky.night > 0.9 and w.sky.moon_dir.y > 0.2, "the moon is up at night")
	w.sky.set_hour(12.5)
	ok(w.sky.sun_dir.y > 0.5 and w.sky.moon_dir.y < 0.0, "the sun is up and the moon down at noon")
	w.sky.set_hour(23.0)
	w.player.teleport(b.lamp_positions[10], 0.0)
	w._update_lamp_lights()
	var lit := 0
	for l in w.lamp_lights:
		if (l as OmniLight3D).visible:
			lit += 1
	ok(lit >= 1, "lamps light the street at night: %d real lights" % lit)
	w.sky.set_hour(12.0)
	w._update_lamp_lights()
	lit = 0
	for l in w.lamp_lights:
		if (l as OmniLight3D).visible:
			lit += 1
	ok(lit == 0, "and not by day")
	# rain is cheap and tight
	ok(w.rain.amount <= 1100 and w.rain.visibility_aabb.size.x <= 60.0, "rain is bounded: %d drops" % w.rain.amount)
	# quality knob
	w.set_quality("low")
	ok(w.quality == 0 and w.sky.sun.directional_shadow_max_distance < 50.0, "low quality shortens shadows")
	w.set_quality(2)
	ok(w.quality == 2 and w.sky.sun.directional_shadow_max_distance >= 90.0, "high quality restores them")
	# camera is pulled back and up
	ok(w.player.dist >= 7.0 and w.player.cam.global_position.distance_to(w.player.global_position + Vector3(0, 1.75, 0)) > 4.0, "the camera sits well behind you")
	# people: few nodes, one manager loop, and they face each other
	hud._after_wake()
	w.sky.set_hour(12.0)
	w.game.sim.advance(14 - w.game.sim.clock)
	w.time_skipped()
	w.player.teleport(Vector3(0, 0, 130), 0.0)
	w.npcs.focus = Vector3(0, 0, 130)
	w.npcs.resync(true)
	for i in 3:
		await process_frame
	var any := ""
	for id in w.npcs.agents:
		if w.npcs.agents[id]["human"] != null:
			any = id
			break
	if any != "":
		var hu: Node3D = w.npcs.agents[any]["human"]
		ok(count_nodes(hu) <= 12, "a person is %d nodes" % count_nodes(hu))
		ok(not hu.is_processing(), "people have no process of their own")
	ok(w.npcs.visible_count() <= w.npcs.MAX_VISIBLE and w.npcs.MAX_VISIBLE <= 40, "the crowd is capped low")
	# two people placed side by side turn to face each other
	var ids: Array = []
	for id in w.npcs.agents:
		if w.npcs.agents[id]["human"] != null and w.npcs.agents[id]["state"] == "outside":
			ids.append(id)
		if ids.size() == 2:
			break
	if ids.size() == 2:
		var a: Dictionary = w.npcs.agents[ids[0]]
		var c: Dictionary = w.npcs.agents[ids[1]]
		a["pos"] = Vector3(0, 0, 130)
		c["pos"] = Vector3(2.0, 0, 130)
		w.npcs._update_partners()
		for i in 120:
			w.npcs._process(0.05)
		var ha: Node3D = a["human"]
		var face := -ha.global_transform.basis.z
		ok(face.dot(Vector3(1, 0, 0)) > 0.8, "idle people face their conversation partner")
	# the crime scene: sagging tape, chalk, markers, a car
	w.refresh_markers()
	var scene := w.get_node_or_null("CrimeScene")
	ok(scene != null and scene.get_node_or_null("Tape") != null and scene.get_node_or_null("Chalk") != null, "the scene has tape and a chalk outline")
	ok(scene != null and scene.get_node_or_null("EvidenceMarkers") != null and scene.get_node_or_null("PatrolCar") != null, "evidence markers and a patrol car")
	# window lights follow who is home: the dead leave their house dark, a newcomer lights theirs
	var gm: RefCounted = w.game
	var sm: RefCounted = gm.sim
	var vic: String = gm.case["victim"]
	var vhome: String = sm.people[vic].home
	var home_id := ""
	for id in sm.order:
		var pp: RefCounted = sm.people[id]
		if id != "player" and id != vic and sm.alive(pp) and pp.home != "" and pp.home != vhome and pp.home.begins_with("house_"):
			pp.location = pp.home
			home_id = id
			break
	var lit_home: String = sm.people[home_id].home
	w.sky.set_hour(21.5)
	b.update_window_lights(sm)
	ok(home_id != "" and b.lot_lit_texel(lit_home) and b.lit_lots.has(lit_home), "a house with somebody home may light its windows at night")
	ok(sm.people[vic].dead and not b.lot_lit_texel(vhome), "the dead victim's house stays dark")
	ok(b.update_window_lights(sm) == 0, "nothing changed, nothing repainted (no per-frame cost)")
	sm.people[home_id].location = "pub"
	var painted: int = b.update_window_lights(sm)
	ok(painted >= 1 and not b.lot_lit_texel(lit_home), "when the last resident goes out, the house goes dark (%d lots repainted)" % painted)
	var empty_lot := ""
	for l in w.game.layout.lots:
		if l["kind"] == "house" and not sm.order.any(func(i): return sm.people[i].home == l["id"]):
			empty_lot = l["id"]
			break
	ok(empty_lot == "" or not b.lot_lit_texel(empty_lot), "an empty house is dark")
	gm._welcome_newcomer()
	var nc: Dictionary = gm.newcomers[-1]
	var np: RefCounted = sm.people[nc["id"]]
	np.location = np.home
	b.update_window_lights(sm)
	ok(b.lot_lit_texel(np.home), "a newly moved-in neighbour lights up %s" % np.home)
	np.dead = true
	b.update_window_lights(sm)
	ok(not b.lot_lit_texel(np.home), "and goes dark if they die")
	ok(b.window_mat.get_shader_parameter("home_map") != null and (b.window_mat.get_shader_parameter("home_rect") as Vector4).z > 0.0, "the window shader has its home map")
	TownGame.delete_save()
	print("world_polish_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
