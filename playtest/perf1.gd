extends SceneTree
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
func info() -> String:
	return "draws=%d prims=%d objs=%d nodes=%d fps=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Engine.get_frames_per_second()]
func _initialize() -> void:
	DetectiveGame.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	for i in 3: await process_frame
	var w: Node3D = hud.world
	hud._after_wake(); w.paused = true
	for i in 6: await process_frame
	print("PERF baseline (no npcs): ", info())
	# put 70 npcs around player
	var p: Vector3 = w.player.global_position
	var k := 0
	for id in w.npcs.agents:
		if id == w.npcs.skip_id: continue
		var a = w.npcs.agents[id]
		a["state"] = "outside"; a["pos"] = p + Vector3(-20 + (k % 12) * 3.0, 0, 4 + (k / 12) * 3.0)
		k += 1
	for i in 6: await process_frame
	print("PERF with npcs: visible=", w.npcs.visible_count(), " ", info())
	var t0 := Time.get_ticks_usec()
	for i in 500: w.npcs._process(0.016)
	print("PERF npc_manager._process x500: ", (Time.get_ticks_usec() - t0) / 500.0, " us per call (217 agents)")
	t0 = Time.get_ticks_usec()
	for i in 100: w.sky.set_hour(12.0 + i * 0.01)
	print("PERF sky.set_hour: ", (Time.get_ticks_usec() - t0) / 100.0, " us")
	t0 = Time.get_ticks_usec()
	for i in 20: w.npcs.resync(false)
	print("PERF npcs.resync x20: ", (Time.get_ticks_usec() - t0) / 20.0, " us")
	# newcomers
	var g = hud.game
	var c = g.case
	var Bot = load("res://tests/case_bot.gd")
	var bot = Bot.new(g.sim, c, g.det); bot.solve()
	g.accuse(c["killer"], c["motive"], c["method"])
	for d in 3:
		g.end_day(); g.dawn()
	print("NEWCOMERS ", g.newcomers.size(), " sim.order ", g.sim.order.size())
	w.npcs.resync(true)
	var nid: String = g.sim.order[-1]
	print("newcomer id ", nid, " agent? ", w.npcs.agents.has(nid), " home ", g.sim.people[nid].home, " door? ", w.builder.doors.has(g.sim.people[nid].home))
	hud.show_case("people")
	await process_frame
	var found := false
	var scan := func(n, f):
		for ch in n.get_children():
			if ch is Label and String(ch.text).to_lower().contains(String(g.sim.people[nid].display).to_lower()): found = true
			f.call(ch, f)
	scan.call(hud, scan)
	print("newcomer shown in HUD people tab labels: ", found, " (suspects only?)")
	print("people on map? ", hud.map != null)
	quit()
