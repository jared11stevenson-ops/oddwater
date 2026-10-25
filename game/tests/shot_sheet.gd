extends SceneTree
## SHOT=/path/prefix xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --path . -s tests/shot_sheet.gd
## Screenshots of the case sheet, the new Case-tab panels, the stake-out and telling menus, and the dread cards. Look at them.
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CaseBot = preload("res://tests/case_bot.gd")
var prefix := ""

func snap(name: String, frames: int = 6) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + name + ".png")

func _initialize() -> void:
	prefix = OS.get_environment("SHOT")
	UiKit.cfg_path = "user://ui_shot2.cfg"
	DirAccess.remove_absolute("user://ui_shot2.cfg")
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = true
	UiKit.force_interactive = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(2)
	hud._close_card() if hud.card != null else null
	hud.close_panel()
	var g: RefCounted = hud.game
	var w: Node3D = hud.world
	var scene: String = g.scene_lot()
	g.examine(scene, "body")
	var bot = CaseBot.new(g)
	bot.examine_scene()
	bot.interview(String(g.case["found_by"]))
	bot.follow_names(2)
	g.remember_them(String(g.family_circle()[0]["id"])) if not g.family_circle().is_empty() else null
	# the sheet, half filled
	hud.open_sheet()
	await snap("sheet_empty", 12)
	var sheet: Control = hud.sheet_screen
	sheet._pick_person(String(g._truth["killer"]))
	sheet._pick_field("when")
	await snap("sheet_when", 6)
	# the full case
	var plan: Dictionary = bot.solve()
	bot.fill_sheet(plan)
	for i in 3:
		await process_frame
		if hud.card != null:
			hud._close_card()
	sheet.refresh()
	sheet._pick_field("who")
	await snap("sheet_who", 6)
	sheet._on_check()
	await snap("sheet_checked", 8)
	sheet._pick_field("how")
	await snap("sheet_how", 6)
	sheet._on_theory()
	await snap("sheet_theory", 6)
	sheet._pick_field("where")
	sheet.query = "pink"
	sheet.search.text = "pink"
	sheet._fill_picker()
	await snap("sheet_where_search", 6)
	hud.close_sheet()
	if hud.card != null:
		hud._close_card()
	# a fresh worked-but-wrong sheet: unsupported stamps
	g.sheet_set("how", "poison" if g._truth["method"] != "poison" else "knife")
	hud.open_sheet()
	hud.sheet_screen._on_check()
	await snap("sheet_unsupported", 8)
	hud.close_sheet()
	# the case tab
	g.det.stress = 78.0
	hud.show_case("case")
	await snap("case_tab", 8)
	hud.scroll.scroll_vertical = 700
	await snap("case_tab_low", 4)
	hud.show_case("accuse")
	await snap("sheet_tab", 6)
	hud.show_case("people")
	await snap("people", 6)
	hud.scroll.scroll_vertical = 500
	await snap("people_low", 4)
	hud._watch_menu(String(g.sim.people[g.persons_of_interest()[0]].home))
	await snap("watch_menu", 6)
	hud._tell_menu(String(g.family_circle()[0]["id"])) if not g.family_circle().is_empty() else null
	await snap("tell_menu", 6)
	hud.show_case("notebook")
	await snap("notebook_whisper", 6)
	hud.scroll.scroll_vertical = 100000
	await snap("notebook_whisper_end", 4)
	hud.close_panel()
	# dread: a night event, the thought, the flicker
	g.det.dread = {}
	g.det.stress = 88.0
	var Dread = load("res://scripts/detective/dread.gd")
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	Dread._raise_event(g, rnd, true)
	hud._dread_card()
	await snap("dread_event", 8)
	hud._dread_choose("watch")
	await snap("dread_response", 6)
	hud._close_card() if hud.card != null else null
	g.det.dread["intr_day"] = -1
	g.det.stress = 82.0
	for d in 40:
		g.sim.day += 1
		g.det.dread["intr_day"] = -1
		if not g.dread_intrusion().is_empty():
			break
	hud._maybe_intrusion()
	await snap("dread_idea", 8)
	hud._dismiss_idea()
	g.serial = {"status": "hunting", "kills": [{"day": 1, "victim": "x", "name": "x", "case": "c", "place": "Marina"}, {"day": 3, "victim": "y", "name": "y", "case": "d", "place": "Larch"}], "news": [], "pressure": 40.0, "third_day": -1, "deadline": -1, "killer": g._truth["killer"], "signature": "a lone folded sock", "next_strike": 6, "nick": "The Sock Man", "trait": "a limp"}
	g.det.dread = {}
	Dread._raise_letter(g, rnd, true)
	hud._dread_card()
	await snap("dread_letter", 8)
	hud._close_card() if hud.card != null else null
	hud.flicker()
	await snap("flicker", 2)
	g.phase = "day"
	g.sim.clock = 12
	hud.open_full_map()
	await snap("map_open", 8)
	hud.full_map.show_card(String(g.sim.people[g.persons_of_interest()[0]].home))
	await snap("map_card", 6)
	hud.close_full_map()
	hud.open_settings()
	await snap("settings", 8)
	hud.settings_ui.close()
	hud.show_case("accuse")
	await snap("charge_tab", 6)
	hud.close_panel()
	if hud.card != null:
		hud._close_card()
	await snap("hud_obj", 20)
	quit()
