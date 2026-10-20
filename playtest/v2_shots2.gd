extends SceneTree
const OUT := "/home/user/oddwater/playtest/shots_v2/"
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
var w: Node3D
var hud: Control
func snap(n: String, frames := 4) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
func small_buttons() -> void:
	var out := []
	_scan(hud, out)
	print("SMALLBTN count=", out.size(), " ", out.slice(0, 12))
func _scan(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is BaseButton and c.is_visible_in_tree():
			var s: Vector2 = c.size
			if s.y < 48 or s.x < 48: out.append("%s %s '%s'" % [c.name, s, c.get("text")])
		_scan(c, out)
func _initialize() -> void:
	DetectiveGame.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await snap("20_title", 3)
	hud = await main._detective_3d(31)
	for i in 3: await process_frame
	w = hud.world; var g = hud.game
	await snap("21_morning_card_start", 40)
	hud._after_wake()
	if hud.tutorial != null:
		hud.tutorial.queue_free(); hud.tutorial = null
	w.paused = true
	w.set_weather_override("clear")
	var scene: String = g.scene_lot()
	w.arrive_at(scene); w._refresh_prompt()
	await snap("22_scene_door", 6)
	w.interact()
	await snap("23_scene_spot_menu")
	small_buttons()
	for s in g.spots(scene): hud._spot(scene, s["id"])
	await snap("24_after_spots_card", 30)
	var k := 0
	while hud.card != null and k < 8:
		k += 1; hud._next_beat()
	hud._dust(scene, "door")
	await snap("25_scene_after")
	hud._step_out()
	var finder: String = g.case["found_by"]
	g.near = [finder]
	hud.show_talk(finder)
	await snap("26_interrogation")
	small_buttons()
	hud._q(finder, "victim", "")
	await snap("27_interrogation_answer")
	hud._ask_about_menu(finder); await snap("27b_ask_about")
	hud._present_menu(finder); await snap("27c_present")
	hud.show_case("case"); await snap("30_tab_case"); small_buttons()
	hud.show_case("notebook"); await snap("31_tab_notes")
	hud.show_case("people"); await snap("32_tab_people")
	hud.show_case("cctv"); await snap("33_tab_cctv")
	hud._pick_cam(g.cameras()[0]["id"]); await snap("33b_cctv_cam")
	hud._calibrate(g.cameras()[0]["id"]); hud._watch(g.cameras()[0]["id"], 24.0, 27.0); await snap("33c_cctv_watch")
	hud.show_case("court"); await snap("34_tab_court")
	hud.show_case("accuse"); await snap("35_tab_accuse")
	hud.show_case("news"); await snap("36_tab_news")
	hud.show_host(); await snap("37_me_sheet")
	hud.close_panel()
	# npc close up: spawn visible
	var ids: Array = w.game.sim.order.slice(0, 40)
	var p: Vector3 = w.player.global_position
	var shown := 0
	for id in ids:
		var a = w.npcs.agents[id]
		if id == w.npcs.skip_id: continue
		a["state"] = "outside"; a["pos"] = p + Vector3(2.0 + shown * 1.4, 0, 3.0 + (shown % 2) * 1.5)
		shown += 1
		if shown >= 6: break
	w.npcs.focus = p
	for i in 5: await process_frame
	w.player.set_process(false)
	w.player.cam.global_position = p + Vector3(4, 1.6, 8.0)
	w.player.cam.look_at(p + Vector3(5, 1.2, 3.0))
	await snap("40_npc_group_close")
	w.player.cam.global_position = p + Vector3(5, 1.55, 5.3)
	w.player.cam.look_at(p + Vector3(3.4, 1.4, 3.0))
	await snap("41_npc_face_close")
	w.player.cam.global_position = p + Vector3(40, 3, 40)
	w.player.cam.look_at(p + Vector3(4, 1, 3.0))
	await snap("42_npc_distance")
	print("PERF npcs ", w.npcs.visible_count(), " nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	# night panel
	w.end_of_day(); await snap("43_night_panel", 6)
	quit()
