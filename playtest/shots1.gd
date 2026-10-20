extends SceneTree
const OUT := "/home/user/oddwater/playtest/shots/"
var w: Node3D
var hud: Control
func snap(n: String, frames := 4) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
func hour(h: float) -> void:
	w.game.sim.clock = int((h - 6.0) * 2.0)
	w.acc = 0.0
	w.paused = true   # hold time
	w.sky.set_hour(h)
func cam(pos: Vector3, look: Vector3, fov := 62.0) -> void:
	w.player.set_process(false)
	w.player.cam.fov = fov
	w.player.cam.global_position = pos
	w.player.cam.look_at(look, Vector3.UP)
func perf(tag: String) -> void:
	print("PERF ", tag, " fps=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " objs=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " vmem=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0, " npcs=", w.npcs.visible_count())
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	hud = await main._detective_3d(31)
	for i in 3: await process_frame
	w = hud.world
	hud._after_wake()
	w.sky.set_weather("clear"); w.rain.emitting = false
	# player at Mercy Street: find a house on mercy_street
	var lots: Array = w.game.layout.lots.filter(func(l): return l["street"] == "mercy_street" and l["kind"] in ["house","home"])
	var l0: Dictionary = lots[3]
	var d: Dictionary = w.builder.doors[l0["id"]]
	w.arrive_at(l0["id"])
	await process_frame
	hud._close_card() if hud.card != null else null
	hour(12.0)
	w.sky._windows.size()
	await snap("01_day_thirdperson")
	perf("day_street")
	var p: Vector3 = w.player.global_position
	# eye height, look along street (east)
	cam(Vector3(p.x, 1.65, p.z + 3.0), Vector3(p.x + 60, 1.5, p.z + 3.0))
	await snap("02_day_eye_along_street")
	cam(Vector3(p.x, 1.65, p.z + 3.0), Vector3(p.x - 60, 1.5, p.z + 3.0))
	await snap("02b_day_eye_west")
	# facing the houses
	cam(Vector3(p.x, 1.65, p.z - 4.0), Vector3(p.x + 8, 3.0, p.z + 20))
	await snap("03_day_houses_facade")
	cam(Vector3(p.x + 20, 6.0, p.z - 10), Vector3(p.x + 40, 2.0, p.z + 20))
	await snap("03b_day_houses_high")
	# aerial
	cam(Vector3(p.x, 90, p.z - 120), Vector3(p.x, 0, p.z + 40), 70.0)
	await snap("04_day_aerial")
	perf("aerial")
	cam(Vector3(0, 300, -400), Vector3(0, 0, 100), 60.0)
	await snap("04b_overview_far")
	perf("overview_far")
	# lake / shore
	cam(Vector3(0, 2.0, -118), Vector3(0, 1.0, -300), 70.0)
	await snap("05_lake_from_shore")
	cam(Vector3(-100, 5.0, -105), Vector3(-30, 0.0, -200), 70.0)
	await snap("05b_lake_shore_angle")
	cam(Vector3(0, 25.0, -60), Vector3(0, 0, -250), 70.0)
	await snap("05c_lake_high")
	# pier
	cam(Vector3(-262, 3, -118), Vector3(-270, 0.5, -170), 70.0)
	await snap("05d_pier")
	# times of day, same eye view
	for t in [[6.0,"06_dawn"],[7.5,"06b_morning"],[17.5,"07_late_afternoon"],[19.0,"08_dusk"],[20.5,"09_twilight"],[23.0,"10_night"],[3.0,"10b_3am"]]:
		hour(t[0])
		cam(Vector3(p.x, 1.65, p.z + 3.0), Vector3(p.x + 60, 1.5, p.z + 3.0))
		await snap(t[1])
	for wt in ["rain","fog","cloudy"]:
		hour(12.0)
		w.sky.set_weather(wt); w.rain.emitting = wt == "rain"
		w.rain.global_position = p + Vector3(0,16,0)
		cam(Vector3(p.x, 1.65, p.z + 3.0), Vector3(p.x + 60, 1.5, p.z + 3.0))
		await snap("11_weather_" + wt, 20)
		perf("weather_" + wt)
	w.sky.set_weather("clear"); w.rain.emitting = false
	hour(12.0)
	# night windows close
	hour(21.5)
	cam(Vector3(p.x, 3.0, p.z - 4.0), Vector3(p.x + 8, 3.0, p.z + 20))
	await snap("12_night_facade")
	quit()
