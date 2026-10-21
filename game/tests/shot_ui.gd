extends SceneTree
## SHOT=/path/prefix xvfb-run godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --path . -s tests/shot_ui.gd
## Screenshots of the polished UI (title, cards, tutorial, case file tabs, interview, night card). Look at them.
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
var prefix := ""

func snap(name: String, frames: int = 6) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + name + ".png")

func _initialize() -> void:
	prefix = OS.get_environment("SHOT")
	UiKit.cfg_path = "user://ui_shot.cfg"
	DirAccess.remove_absolute("user://ui_shot.cfg")
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await snap("title", 20)
	var hud: Control = await main._detective_3d(31)
	await snap("card_wake", 25)
	hud.card_body.visible_ratio = 1.0
	await snap("card_wake_done", 4)
	hud._after_wake()
	await snap("tut1", 20)
	for i in range(2, 7):
		hud.tutorial._next()
		await snap("tut%d" % i, 10)
	hud.tutorial._next() if hud.tutorial != null else null
	await snap("hud", 10)
	var g: RefCounted = hud.game
	var w: Node3D = hud.world
	var scene: String = g.scene_lot()
	w.arrive_at(scene)
	await snap("hud_at_scene", 15)
	w.interact()
	await snap("inside", 8)
	for s in g.spots(scene):
		hud._spot(scene, s["id"])
	hud._close_card() if hud.card != null else null
	while hud.card != null:
		hud._next_beat()
	await snap("inside_after", 8)
	hud._dust(scene, "door")
	hud._step_out()
	g.near = [g._truth["found_by"]]
	hud.show_talk(g._truth["found_by"])
	await snap("talk", 8)
	hud._q(g._truth["found_by"], "victim", "")
	hud._close_card() if hud.card != null else null
	await snap("talk2", 8)
	hud.show_case("notebook")
	await snap("notes", 8)
	var CaseBot = load("res://tests/case_bot.gd")
	var bot = CaseBot.new(g)
	bot.solve()
	hud.nb_open["c_body"] = true
	hud.show_case("notebook")
	await snap("notes_big", 8)
	hud.nb_filter = "testimony"
	hud.show_case("notebook")
	await snap("notes_testimony", 8)
	hud.nb_filter = "all"
	hud.show_case("case"); await snap("case", 8)
	hud.show_case("people"); await snap("people", 8)
	hud.show_case("news"); await snap("news", 8)
	hud.show_case("cctv"); await snap("cctv", 8)
	hud._pick_cam(g.cameras()[0]["id"]); await snap("cctv_cam", 8)
	hud.show_case("court"); await snap("court", 8)
	hud.show_case("accuse")
	hud._pick("culprit", g._truth["killer"]); hud._pick("motive", g._truth["motive"]); hud._pick("method", g._truth["method"])
	await snap("accuse", 8)
	g.det.points = 2
	hud.show_host(); await snap("sheet", 8)
	hud.close_panel()
	hud._main_menu(); await snap("menu", 8)
	hud.open_settings(); await snap("settings", 8)
	hud.settings_ui.close()
	hud.close_panel()
	w.end_of_day()
	await snap("night_card", 10)
	quit()
