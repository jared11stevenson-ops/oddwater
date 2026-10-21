extends SceneTree
## godot --headless --path game -s tests/detective_game_tests.gd : the detective game model.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var g := DetectiveGame.new(21)
	ok(g.host == "player" and g.sim.day == 1 and g.sim.clock == 0 and g.phase == "day", "you wake as yourself on Day 1")
	ok(g._truth["status"] == "open" and g.sim.people[g._truth["victim"]].dead, "a murder has already happened")
	ok(g.briefing().contains("found") and g.briefing().contains("dead"), "the Sheriff's call: %s" % g.briefing())
	ok(g.sim.history.has(0) and g.sim.where_was(g._truth["killer"], 0, 5) != "", "last night's evening is on record")
	# the day: examine, ask, time passes in half hours
	var t0: int = g.sim.clock
	var sc: String = g.scene_lot()
	g.me().location = sc
	var spots: Array = g.spots(sc)
	ok(spots.size() == 6, "the scene offers six things to examine")
	var r: Dictionary = g.examine(sc, "body")
	ok(g.det.has("c_body") and r["learned"].size() >= 1, "examining the body teaches something")
	for s in spots:
		g.examine(sc, s["id"])
	ok(g.sim.clock == t0, "while you're in the panel the town holds its breath")
	var ft: int = g.flush_time()
	ok(g.sim.clock > t0 and ft > 0, "and when you step away the time has passed (%d half hours)" % ft)
	ok(g.objective() != "", "there is always a next thread: %s" % g.objective())
	var neighbor: String = g._truth["found_by"]
	var a: Dictionary = g.ask(neighbor, "victim")
	ok(a["text"] != "" and g.det.statements.size() >= 1, "people answer, and it is written down")
	# the day ends, nobody swaps
	g.end_day()
	var rep: Dictionary = g.report
	var h: String = g.dawn()
	ok(h == "player" and g.host == "player" and g.sim.day == 2, "you wake as you, the next morning")
	ok(g.det.has("c_body"), "and your notebook is intact")
	# lab
	var g2 := DetectiveGame.new(22)
	g2.me().location = g2.scene_lot()
	g2.examine(g2.scene_lot(), "floor")
	var had: bool = g2.det.has("c_dropped")
	var lr: Dictionary = g2.submit_lab("c_dropped") if had else {"text": ""}
	g2.end_day(); g2.dawn()
	ok((not had) or g2.det.has("lab_c_dropped"), "the lab reports next morning")
	# save and load
	g.save("user://dg_save.json")
	var g3: RefCounted = DetectiveGame.load_detective("user://dg_save.json")
	ok(g3 != null and g3.det.has("c_body") and g3._truth["killer"] == g._truth["killer"] and g3.sim.day == g.sim.day, "a saved investigation resumes")
	ok(g3.sim.people[g3._truth["victim"]].dead and g3.sim.history.size() >= 1, "the dead stay dead, the history stays")
	# an accusation
	var g4 := DetectiveGame.new(23)
	var res: Dictionary = g4.accuse(g4.suspects()[0], "money", "blunt")
	ok(res.has("verdict") and g4.chronicle.size() >= 1, "an accusation gets a verdict")
	DetectiveGame.delete_save("user://dg_save.json")
	ok(not FileAccess.file_exists("user://dg_save.json"), "delete_save removes the detective save file")
	print("detective_game_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
