extends SceneTree
## godot --headless --path game -s tests/town3d_tests.gd : the 3D game loop, played by a robot through the real world and HUD.

const MainScene = preload("res://scenes/main.tscn")
const PathGrid = preload("res://scripts/world3d/path_grid.gd")
const TownGame = preload("res://scripts/sim/town_game.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	TownGame.delete_save()
	var main: Control = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var hud: Control = await main._town_3d(88)
	await process_frame
	var w: Node3D = hud.world
	var g: RefCounted = w.game
	# the world exists
	ok(w.builder.doors.size() >= 120, "every lot has a door: %d" % w.builder.doors.size())
	ok(w.builder.colliders.get_child_count() > 100, "buildings are solid: %d colliders" % w.builder.colliders.get_child_count())
	ok(w.player.human != null and w.player.visible, "you have a body")
	ok(hud.card != null, "the morning card is up")
	hud._after_wake()
	ok(not w.paused and not hud.panel.visible, "the town runs once you start the day")
	# routes
	var grid: RefCounted = PathGrid.new(g.layout.spec)
	var a := Vector3(-300.0, 0, 20.0)
	var b := Vector3(200.0, 0, 380.0)
	var route: Array = grid.route(a, b)
	ok(route[0] == a and route[-1] == b and route.size() >= 5, "a route from here to there along the streets")
	var finite := true
	for p in route:
		if not is_finite((p as Vector3).x) or not is_finite((p as Vector3).z):
			finite = false
	ok(finite and PathGrid.length(route) >= a.distance_to(b), "and it is sensible (%.0f m for a %.0f m trip)" % [PathGrid.length(route), a.distance_to(b)])
	# your own door
	var home: String = g.me().home
	var d: Dictionary = w.builder.doors[home]
	w.player.teleport(d["front"], d["yaw"])
	w._refresh_prompt()
	ok(w.prompt.get("kind", "") == "enter" and w.prompt["id"] == home, "at your door the game offers to go inside")
	w.interact()
	ok(w.inside == home and not w.player.visible and hud.panel.visible and w.paused, "you are inside, and the menu is up")
	ok(g.me().location == home, "the sim agrees where you are")
	var t0: int = g.sim.clock
	hud.do_action("relax")
	ok(g.sim.clock > t0, "an action passes time")
	hud._step_out()
	ok(w.inside == "" and w.player.visible and not w.paused, "you step back out")
	# the town around you at midday
	g.sim.advance(14 - g.sim.clock)
	w.time_skipped()
	w.player.teleport(Vector3(0, 0, 130), 0.0)
	w.npcs.focus = Vector3(0, 0, 130)
	w.npcs.resync(true)
	for i in 3:
		await process_frame
	ok(w.npcs.visible_count() > 0, "there are people about at midday: %d bodies" % w.npcs.visible_count())
	ok(w.npcs.visible_count() <= w.npcs.MAX_VISIBLE, "the crowd is bounded")
	# talk to someone
	var someone := ""
	for id in w.npcs.agents:
		if w.npcs.agents[id]["human"] != null:
			someone = id
			break
	if someone != "":
		var pos: Vector3 = w.npcs.agents[someone]["pos"]
		w.player.teleport(pos + Vector3(0, 0, 1.6), 0.0)
		w.npcs.focus = pos
		w._refresh_prompt()
		ok(w.prompt.get("kind", "") in ["talk", "enter"], "next to somebody the game offers something")
		if w.prompt.get("kind", "") == "talk":
			w.interact()
			ok(hud.panel.visible, "talking opens the conversation")
			var clock0: int = g.sim.clock
			var r: Dictionary = hud.talk(someone, "chat")
			ok(r.has("text") and r["text"] != "", "they answer: %s" % r.get("text", ""))
			ok(g.sim.clock == clock0, "a chat doesn't spend town time in 3D")
			hud.close_panel()
	# real-time clock
	var c1: int = g.sim.clock
	w.acc = w.tick_seconds - 0.01
	w._process(0.05)
	ok(g.sim.clock == c1 + 1, "half an hour passes as time flows")
	# fast trip
	hud.show_place("pink_heron")
	var r2: Dictionary = hud.go("pink_heron")
	ok(r2.get("ok", false), "the map's 'go here' works")
	ok(w.player.global_position.distance_to(w.builder.doors["pink_heron"]["front"]) < 2.0, "and puts you at the door")
	# light follows the clock
	w.sky.set_hour(12.5)
	var noon_e: float = w.sky.sun.light_energy
	w.sky.set_hour(23.0)
	ok(w.sky.night > 0.9 and w.sky.sun.light_energy < noon_e * 0.4, "night falls: dark sky, warm windows")
	w.sky.set_hour(10.0)
	# the end of the day, the night and the next morning
	var guard := 0
	var host0: String = g.host
	while g.phase == "day" and guard < 60:
		guard += 1
		w._tick()
	ok(g.phase == "night" and g.report.has("done"), "the day ends and there is a report")
	ok(hud.panel.visible, "the night panel is up")
	hud.card = null
	var nid: String = hud.next_morning()
	ok(nid != host0 and g.host == nid and g.phase == "day" and g.sim.clock == 0, "a new person wakes at dawn: %s" % g.me().display)
	ok(w.player.visible and w.player.human != null and w.npcs.skip_id == nid, "and you are in their body at their door")
	# resume
	g.save()
	var main2: Control = MainScene.instantiate()
	get_root().add_child(main2)
	await process_frame
	var hud2: Control = await main2._town_3d(1, true)
	await process_frame
	ok(hud2.world.game.host == nid and hud2.world.game.sim.day == g.sim.day, "Continue brings the 3D town back")
	TownGame.delete_save()
	print("town3d_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
