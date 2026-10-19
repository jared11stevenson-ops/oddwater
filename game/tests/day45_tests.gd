extends SceneTree
## godot --headless --path game -s tests/day45_tests.gd : speech, radio, hymn, and Day 4/5 seals.

const GameState = preload("res://scripts/core/game_state.gd")
const Speech = preload("res://scripts/core/speech.gd")
const Radio = preload("res://scripts/core/radio.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# --- speech: tradition-keeping vs. truth-telling lands differently
	var tradition := Speech.new("town_hall")
	for pick in [0, 1, 0, 1]:   # nothing to report / tradition first / ask volunteers / nothing further
		tradition.choose(pick)
	var trad := tradition.mood()
	var bold := Speech.new("town_hall")
	for pick in [1, 0, 1, 0]:   # something to report / who's it a promise to / skip lamp / resign
		bold.choose(pick)
	ok(bold.finished() and tradition.finished(), "four beats each")
	ok(bold.flags.get("delphine_resigned", false), "the bold route announces the resignation")
	ok(not tradition.flags.has("delphine_resigned"), "the safe route does not")
	ok(bold.seg["waking"] > tradition.seg["waking"] and bold.seg["holdfast"] < tradition.seg["holdfast"], "bold speech moves the Waking up and the Holdfast down")
	ok(bold.notes_gain["nerve"] > tradition.notes_gain.get("nerve", 0), "bold speech earns nerve")
	ok(tradition.outcome() in ["warm", "mixed", "cold"] and bold.outcome_text().length() > 10, "outcomes exist (%s %.0f vs %s %.0f)" % [tradition.outcome(), trad, bold.outcome(), bold.mood()])
	ok(Speech.new("town_hall").choose(99).is_empty(), "bad choice ignored")
	var cap := Speech.new("town_hall")
	for i in 4: cap.choose(0)
	ok(cap.choose(0).is_empty(), "no choices after the last beat")
	# --- radio
	var r := Radio.new("dedication_hour")
	ok(r.letters() == "_____", "nothing picked")
	for i in 5:
		ok(r.choose(i, r.def["slots"][i]["correct"]), "slot %d correct" % i)
	ok(r.letters() == "FAIRW" and r.spells() and r.stars() == 3, "the right songs spell FAIRW")
	var w := Radio.new("dedication_hour")
	for i in 5: w.choose(i, 3 if i != 0 else 0)
	ok(w.complete() and not w.spells(), "wrong songs do not spell it")
	ok(w.stars() < 3, "and score lower")
	ok(r.letters() + r.def["next_nights"] == "FAIRWATER", "tonight plus the playlist sheet: FAIRWATER")
	ok(not r.choose(9, 0) and not r.choose(0, 9), "bad slot or option ignored")
	# --- hymn
	var g := GameState.new()
	var mood0 := g.town_mood
	g.apply_hymn(false)
	ok(g.flags["hymn_decided"] and not g.flags["hymn_aired"] and g.town_mood == mood0, "declining changes nothing in the town")
	g.apply_hymn(true)
	ok(g.flags["hymn_aired"] and g.town_mood == mood0 - 25 and g.is_foggy() == (g.town_mood < 30), "airing it frightens the town")
	ok(g.suspicion.get_s("silas") == 10, "the Awakened watch you")
	var path := "user://flags.json"
	ok(g.save_to(path), "save")
	var h := GameState.new()
	ok(h.load_from(path) and h.flags.get("hymn_aired", false), "flags survive a save")
	# --- seals: the vault needs the vault key AND the cards tied together
	var d := GameState.new()
	for i in 3: for j in 5: d.advance()   # Day 4
	ok(d.day == 4 and d.current_life()["id"] == "delphine", "Day 4 is Delphine")
	d.board.add_evidence("LF-035"); d.board.add_evidence("LF-034"); d.board.add_evidence("LF-011")
	for id in ["LF-035", "LF-034", "LF-011"]: d.board.pin(id, "what")
	ok(d.board.testable().has("S17") and d.board.testable().has("S16"), "vault seals are testable with the key")
	ok(not d.board.try_link_test("S17", 4), "untied cards do not prove it")
	d.board.link("LF-035", "LF-034"); d.board.link("LF-035", "LF-011")
	ok(d.board.try_link_test("S17", 4) and d.board.try_link_test("S16", 4), "tied: S17 (falsified census) and S16 (913 = 701 + 212)")
	var e := GameState.new()
	for i in 4: for j in 5: e.advance()   # Day 5
	ok(e.current_life()["id"] == "vern" and e.board.tools_available["reel"], "Day 5 gives the Reel")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
