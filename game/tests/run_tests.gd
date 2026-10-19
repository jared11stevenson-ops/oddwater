extends SceneTree
## Run: godot --headless --path game -s tests/run_tests.gd
## Exit code is the number of failed checks.

const Data = preload("res://scripts/core/data.gd")
const Notes = preload("res://scripts/core/notes.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const CaseBoard = preload("res://scripts/core/case_board.gd")
const Suspicion = preload("res://scripts/core/suspicion.gd")

var fails := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", msg)


func _initialize() -> void:
	test_data()
	test_notes()
	test_board()
	test_abilities()
	test_suspicion()
	test_day_loop()
	test_remnants_and_overlap()
	test_endings()
	test_save_roundtrip()
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)


func test_data() -> void:
	print("data")
	var seals: Array = Data.load_json("seals.json")
	ok(seals.size() == 40, "40 seals")
	var per := {}
	for s in seals:
		per[s["layer"]] = int(per.get(s["layer"], 0)) + 1
	ok(per == {"L1": 6, "L2": 8, "L3": 10, "L4": 8, "L5": 4, "O": 4}, "layer counts %s" % per)
	var lives: Array = Data.load_json("lives.json")
	ok(lives.size() == 14, "13 lives + prop room")
	var days := {}
	var tools := {"any": true, "map": true, "board": true, "roll": true}
	for l in lives:
		days[l["day"]] = true
		tools[l["proof_tool"]] = true
	ok(days.size() == 14, "unique days 1..14")
	for s in seals:
		ok(tools.has(s["tool"]), "seal %s tool %s exists" % [s["id"], s["tool"]])
	# every ability references a real layer and is attainable
	var board := CaseBoard.new()
	for a in board.ability_defs:
		ok(board.layer_total(a["layer"]) >= int(a["count"]), "ability %s attainable" % a["id"])


func test_notes() -> void:
	print("notes")
	var n := Notes.new()
	n.add("warmth", 250)
	ok(n.get_note("warmth") == 100, "clamp high")
	n.add("nerve", -250)
	ok(n.get_note("nerve") == -100, "clamp low")
	ok(n.dominant() in ["warmth", "nerve"], "dominant")
	n.add("bogus", 5)
	ok(n.get_note("bogus") == 0, "unknown note ignored")
	var copy: RefCounted = Notes.from_dict(n.to_dict())
	ok(copy.get_note("warmth") == 100, "dict roundtrip")


func test_board() -> void:
	print("board")
	var b := CaseBoard.new()
	ok(not b.pin("LF-043", "what"), "cannot pin unfound evidence")
	b.add_evidence("LF-043")
	ok(b.pin("LF-043", "what"), "pin found evidence")
	ok(not b.pin("LF-043", "banana"), "bad question refused")
	ok(b.block_reason("S23").begins_with("needs_tool"), "S23 needs the dental overlay")
	b.set_tool("dental_overlay", true)
	ok(b.can_test("S23"), "S23 testable with tool + pinned evidence")
	ok(b.complete_test("S23", 1), "S23 sealed")
	ok(not b.complete_test("S23", 1), "cannot seal twice")
	b.add_evidence("LF-055")
	b.add_evidence("LF-056")
	b.pin("LF-055", "who")
	b.pin("LF-056", "who")
	ok(b.link("LF-055", "LF-056"), "link")
	ok(not b.link("LF-056", "LF-055"), "duplicate link refused")


func test_abilities() -> void:
	print("abilities")
	var b := CaseBoard.new()
	ok(b.abilities().is_empty(), "none at start")
	for id in ["S01", "S02", "S03"]:
		b.seals[id] = 1
	ok(b.has_ability("take_your_minute"), "3 L1 seals -> Take Your Minute")
	ok(not b.has_ability("wave"), "not Wave yet")
	for id in ["S37", "S38", "S39"]:
		b.seals[id] = 1
	ok(not b.has_ability("fair_water"), "needs all 4 omega")
	b.seals["S40"] = 1
	ok(b.has_ability("fair_water"), "all 4 omega -> Fair Water")


func test_suspicion() -> void:
	print("suspicion")
	var s := Suspicion.new(Data.load_json("tuning.json"))
	s.raise("cal", 85)
	ok(s.stages_test("cal"), "stages a test at 80+")
	s.decay_overnight(false)
	ok(s.get_s("cal") == 70, "clear night decays 15")
	s.decay_overnight(true)
	ok(s.get_s("cal") == 66, "foggy night decays 4")
	s.raise("cal", 999)
	ok(s.get_s("cal") == 100, "clamped")


func play_day(g: RefCounted) -> void:
	for i in 5:
		g.advance()


func test_day_loop() -> void:
	print("day loop")
	var g := GameState.new()
	ok(g.day == 1 and g.phase == GameState.Phase.WAKE, "starts Day 1 WAKE")
	ok(g.current_life()["id"] == "mags", "Day 1 is Mags")
	ok(g.board.tools_available["dental_overlay"], "dental overlay on Day 1")
	ok(not g.board.tools_available["reply"], "reply not yet")
	play_day(g)
	ok(g.day == 2 and g.current_life()["id"] == "jo", "Day 2 is Jo")
	ok(not g.board.tools_available["dental_overlay"], "tool gone on Day 2 (no remnant liking)")
	for i in 14:
		play_day(g)
	ok(g.phase == GameState.Phase.ENDED, "ends after Day 15")
	ok(g.ending == "staying_day", "no seals -> Staying Day")


func test_remnants_and_overlap() -> void:
	print("remnants")
	var g := GameState.new()
	g.notes.add("warmth", 60)
	g.notes.add("nerve", 40)
	play_day(g)
	ok(g.remnants.has_remnant("mags"), "Mags remnant exists")
	ok(g.remnants.willing("mags"), "warm Mags remnant is willing")
	ok(g.board.tools_available["dental_overlay"], "Overlap: Mags runs her tool on Day 2")
	# Shed needs the ability
	var g2 := GameState.new()
	g2.notes.add("warmth", 80)
	g2.notes.add("nerve", 80)
	g2.advance(); g2.advance()
	g2.advance("warmth")
	ok(g2.remnants.by_life["mags"]["notes"]["nerve"] == 80, "no Shed ability: keep arg ignored")
	var g3 := GameState.new()
	for id in ["S33", "S34", "S35"]:
		g3.board.seals[id] = 1
	g3.notes.add("warmth", 80)
	g3.notes.add("nerve", 80)
	g3.advance(); g3.advance()
	g3.advance("warmth")
	ok(g3.remnants.by_life["mags"]["notes"]["warmth"] == 80, "Shed keeps chosen note")
	ok(g3.remnants.by_life["mags"]["notes"]["nerve"] == 40, "Shed decays the rest")


func test_endings() -> void:
	print("endings")
	var g := GameState.new()
	for id in ["S37", "S38", "S39", "S40"]:
		g.board.seals[id] = 1
	ok(g.ending_for() == "fair_water", "omega seals -> Fair Water")
	var g2 := GameState.new()
	for id in ["S18", "S19", "S29", "S15", "S16", "S17", "S20", "S21", "S22"]:
		g2.board.seals[id] = 1
	ok(g2.ending_for() == "low_water", "Plug seals -> Low Water")
	var g3 := GameState.new()
	for id in ["S01", "S02", "S03", "S04", "S05", "S06", "S07", "S08", "S09", "S10", "S15", "S16", "S17", "S20", "S21", "S22"]:
		g3.board.seals[id] = 1
	ok(g3.ending_for() == "same_time_tomorrow", "L1-L3 strong -> Same Time Tomorrow")


func test_save_roundtrip() -> void:
	print("save")
	var g := GameState.new()
	g.notes.add("candor", 33)
	g.board.add_evidence("LF-004")
	g.board.seals["S01"] = 1
	g.suspicion.raise("silas", 42)
	g.advance(); g.advance(); g.advance()
	var path := "user://test_save.json"
	ok(g.save_to(path), "saved")
	var h := GameState.new()
	ok(h.load_from(path), "loaded")
	ok(h.day == g.day and h.phase == g.phase, "day/phase restored")
	ok(h.board.seals.has("S01") and h.board.evidence.has("LF-004"), "board restored")
	ok(h.suspicion.get_s("silas") == 42, "suspicion restored")
	ok(h.remnants.has_remnant("mags"), "remnant restored")
