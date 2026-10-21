extends SceneTree
## godot --headless --path game -s tests/narrator_tests.gd : the told story: a cold open that never spoils, beats at the right moments, an episode at the end.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var leaks := 0
	var titles: Dictionary = {}
	for s in range(1, 13):
		var g := DetectiveGame.new(s)
		var c: Dictionary = g._truth
		var open: String = g.opening()
		var v := CaseEngine.first(g.sim, c["victim"])
		var kname := CaseEngine.name_of(g.sim, c["killer"])
		if not open.contains(v) or not open.contains(CaseEngine.name_of(g.sim, c["found_by"])):
			ok(false, "seed %d: the cold open names the dead and the finder" % s)
		if open.contains(kname) or open.contains(String(c["motive_thing"])) or open.contains(String(c["held_back"])):
			leaks += 1
		ok(open.split("\n\n").size() == 4, "seed %d: four paragraphs" % s)
		titles[Narrator.title(g.sim, c)] = true
	ok(leaks == 0, "the cold open never gives away the killer, the motive or the detail (%d leaks)" % leaks)
	ok(titles.size() >= 6, "episodes get different titles: %d" % titles.size())
	# beats arrive at the right moments, once
	var g := DetectiveGame.new(7)
	ok(g.pending_beats.is_empty(), "nothing has happened yet")
	g.me().location = g.scene_lot()
	g.examine(g.scene_lot(), "body")
	ok(g.pending_beats.size() >= 1 and g.pending_beats[0]["title"] == "THE SCENE", "reading the body starts the story: %s" % [g.pending_beats.map(func(b): return b["title"])])
	g.examine(g.scene_lot(), "body")
	var n: int = g.pending_beats.size()
	g.examine(g.scene_lot(), "body")
	ok(g.pending_beats.size() == n, "a beat fires only once")
	var odd := false
	for b in g.pending_beats:
		if b["title"] == "THE DETAIL THAT DIDN'T FIT":
			odd = true
			ok(b["text"].contains(g._truth["held_back"]), "the odd detail is told in full")
	ok(odd and g.det.has("c_odd"), "the detail that didn't fit is a real, findable clue")
	while not g.take_beat().is_empty():
		pass
	ok(g.pending_beats.is_empty(), "beats can be taken one at a time")
	# the episode
	var CaseBot = load("res://tests/case_bot.gd")
	var bot = CaseBot.new(g)
	bot.solve()
	var res: Dictionary = g.accuse(g._truth["killer"], g._truth["motive"], g._truth["method"])
	var ep: Dictionary = res["episode"]
	ok(res["verdict"] == "convicted" and ep["text"].contains("THE TRUTH") and ep["text"].contains(CaseEngine.name_of(g.sim, g._truth["killer"])), "the episode tells the truth at the end")
	ok(ep["text"].contains("THE DETAIL") and ep["text"].contains(g._truth["held_back"]), "and explains the detail that didn't fit")
	ok(ep["text"].contains(Data_closer(g._truth["motive"])), "and ends on a reflective thought")
	ok(g.episodes.size() == 1 and g.episodes[0]["title"] == ep["title"], "the story goes in the archive")
	# a wrong accusation gets a different story
	var g2 := DetectiveGame.new(8)
	var innocent: String = g2._truth["suspects"].filter(func(x): return x != g2._truth["killer"])[0]
	var Cl = load("res://scripts/detective/claims.gd")
	g2.det.learn({"id": "x1", "title": "x", "text": "x", "kind": "testimony", "source": "", "day": 1, "claims": Cl.emit(g2._truth, [Cl.make("seen", innocent, "seen_going_out", "", 25.0, "", 1.0, "false", 26.0), Cl.make("said", innocent, "motive_quarrel", "", -1.0, "", 1.0, "false")], "", "x")})
	var r2: Dictionary = g2.accuse(innocent, "money", "blunt")
	ok(r2["episode"]["text"].contains("It was not who you said"), "a wrong accusation is told as a failure, not a victory")
	# saves keep the archive and the beats
	g.save("user://nar_save.json")
	var g3: RefCounted = DetectiveGame.load_detective("user://nar_save.json")
	ok(g3.episodes.size() == 1 and g3.beats_seen.has("first_scene"), "the archive and the beats survive a save")
	DetectiveGame.delete_save("user://nar_save.json")
	print("narrator_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)

func Data_closer(motive: String) -> String:
	var cb: Dictionary = load("res://scripts/core/data.gd").load_json("detective/casebook.json")
	return String(cb["closers"][motive]).substr(0, 30)
