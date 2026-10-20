extends SceneTree
## godot --headless --path game -s tests/detective3d_tests.gd : a robot plays a murder case through the real 3D world and HUD.

const MainScene = preload("res://scenes/main.tscn")
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func buttons(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(buttons(c))
	return out

func by_name(root: Node, n: String) -> Button:
	for b in buttons(root):
		if String(b.name) == n or (String(b.name).begins_with(n) and String(b.name).substr(n.length()).is_valid_int()):
			return b
	return null

func _initialize() -> void:
	DetectiveGame.delete_save()
	var main: Control = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	await process_frame
	var w: Node3D = hud.world
	var g: RefCounted = hud.game
	ok(g is DetectiveGame and g.host == "player" and g.sim.day == 1, "a new case starts on Day 1 as yourself")
	ok(hud.card != null and hud.get_node("TopBar").has_node("CaseBtn"), "the Sheriff's call is up and there is a Case button")
	ok(hud.obj_label.text.contains("Examine the crime scene"), "the objective points you at the scene: %s" % hud.obj_label.text)
	hud._after_wake()
	# the scene is marked in the world
	ok(w._marker != null, "the scene is marked with tape and a beam of light")
	# get to the scene, go in, look at everything
	var scene: String = g.scene_lot()
	w.arrive_at(scene)
	w._refresh_prompt()
	ok(w.prompt.get("kind", "") == "enter" and w.prompt["id"] == scene, "at the scene door the game offers to go in")
	w.interact()
	ok(w.inside == scene and hud.panel.visible, "you are in the scene")
	ok(by_name(hud.box, "Spot_body") != null and by_name(hud.box, "Spot_desk") != null, "the scene menu lists what to examine")
	for s in g.spots(scene):
		hud._spot(scene, s["id"])
	ok(g.det.has("c_body") and g.det.has("c_desk"), "examining teaches: %d entries" % g.det.order.size())
	ok(hud.card != null and hud.card_body != null, "the storyteller steps in with an interlude")
	var interludes := 0
	while hud.card != null and interludes < 8:
		interludes += 1
		hud._next_beat()
	ok(interludes >= 2 and hud.card == null, "interludes play one after another (%d)" % interludes)
	hud._dust(scene, "door")
	ok(g.det.order.any(func(e): return String(e).begins_with("print_")), "you can dust for prints")
	hud.show_case("cctv")
	hud._pick_cam(g.cameras()[0]["id"])
	hud._calibrate(g.cameras()[0]["id"])
	hud._watch(g.cameras()[0]["id"], 24.0, 27.0)
	ok(g.det.calibrated.get(g.cameras()[0]["id"], false), "you can check a camera's clock and watch its footage")
	hud._circle(g.suspects()[0])
	ok(hud.panel.visible, "you can look at the people around a suspect")
	hud.show_case("notebook")
	ok(by_name(hud.box, "Entry_c_body") != null, "the notebook lists it")
	hud._entry("c_dropped") if g.det.has("c_dropped") else null
	if g.det.has("c_dropped"):
		ok(by_name(hud.box, "Lab") != null, "a dropped item can go to the lab")
		hud._lab("c_dropped")
	hud._step_out()
	ok(w.inside == "" and not w.paused, "you step back out")
	ok(g.sim.clock > 0, "the examination used up time")
	# talk to the finder
	var finder: String = g.case["found_by"]
	g.near = [finder]
	hud.show_talk(finder)
	ok(by_name(hud.box, "Q_alibi") != null and by_name(hud.box, "Q_show") != null, "the interrogation menu is there")
	hud._q(finder, "victim", "")
	ok(hud.last_talk.get("text", "") != "" and g.det.statements.size() >= 1, "they answer, and it is noted")
	hud._ask_about_menu(finder)
	hud._present_menu(finder)
	hud.show_talk(finder)
	hud._friendly(finder)
	hud.close_panel()
	# a thorough run through the model, then the accusation through the HUD
	var CaseBot = load("res://tests/case_bot.gd")
	var bot = CaseBot.new(g.sim, g.case, g.det)
	var r: Dictionary = bot.solve()
	hud.show_case("people")
	ok(by_name(hud.box, "Warrant_" + g.case["killer"]) != null, "the people tab has warrants")
	hud.show_case("accuse")
	hud._pick("culprit", g.case["killer"])
	hud._pick("motive", g.case["motive"])
	hud._pick("method", g.case["method"])
	await process_frame
	var acc := by_name(hud.box, "Accuse")
	ok(acc != null and not acc.disabled, "the accusation is ready to make (%s %s %s %s)" % [acc != null, hud.sel_culprit, hud.sel_motive, hud.sel_method])
	hud._accuse()
	ok(g.solved() and hud.card != null, "a thorough detective closes the case")
	ok(w._marker == null, "and the tape comes down")
	ok(g.det.cases_solved == 1 and g.det.xp > 0, "and earns XP")
	# nights and mornings: you stay you
	hud._close_card()
	hud.show_host()
	w.end_of_day()
	ok(g.phase == "night" and by_name(hud.box, "Sleep") != null, "night: you can sleep")
	hud.card = null
	hud.next_morning()
	ok(g.host == "player" and g.sim.day == 2 and w.player.visible, "you wake as yourself on Day 2")
	# continue
	g.save()
	var main2: Control = MainScene.instantiate()
	get_root().add_child(main2)
	await process_frame
	var hud2: Control = await main2._detective_3d(1, true)
	ok(hud2.game.case["killer"] == g.case["killer"] and hud2.game.det.cases_solved == 1, "Continue restores the investigation")
	DetectiveGame.delete_save()
	print("detective3d_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
