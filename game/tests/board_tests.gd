extends SceneTree
## godot --headless --path game -s tests/board_tests.gd

const GameState = preload("res://scripts/core/game_state.gd")
const Data = preload("res://scripts/core/data.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var ev: Dictionary = Data.load_json("evidence.json")
	var fragments_ok := true
	for id in ev:
		if not (ev[id].has("title") and ev[id].has("text")):
			fragments_ok = false
	ok(fragments_ok, "every evidence entry has a title and text")
	var g := GameState.new()
	var b: RefCounted = g.board
	# S23 on Day 1: needs the ledger pinned (single card), and the dental overlay tool (Day 1)
	ok(not b.testable().has("S23"), "not testable before finding the ledger")
	b.add_evidence("LF-043")
	ok(not b.testable().has("S23"), "found but not pinned")
	b.pin("LF-043", "what")
	ok(b.testable().has("S23"), "pinned + tool -> testable")
	ok(b.try_link_test("S23", 1) and b.seals.has("S23"), "S23 sealed by the generic test")
	# S25: two cards, must be joined by a string
	for id in ["LF-055", "LF-056"]:
		b.add_evidence(id); b.pin(id, "who")
	ok(b.can_test("S25"), "S25 can be attempted")
	ok(not b.try_link_test("S25", 1), "pinned but not linked: the test fails")
	ok(not b.seals.has("S25"), "and does not seal")
	b.link("LF-055", "LF-056")
	ok(b.try_link_test("S25", 1), "linked: sealed")
	# three-card chain
	var c := GameState.new().board
	ok(c.links_connect(["a"]) and c.links_connect([]), "trivial sets connect")
	for id in ["LF-004", "LF-033", "LF-008"]:
		c.add_evidence(id); c.pin(id, "what")
	c.link("LF-004", "LF-033")
	ok(not c.links_connect(["LF-004", "LF-033", "LF-008"]), "two of three joined is not enough")
	c.link("LF-033", "LF-008")
	ok(c.links_connect(["LF-004", "LF-033", "LF-008"]), "a chain connects all three")
	# a tool on the wrong day blocks the test
	var d := GameState.new()
	d.board.add_evidence("LF-043"); d.board.pin("LF-043", "what")
	for i in 5: d.advance()
	ok(d.day == 2 and not d.board.try_link_test("S23", 2), "on Day 2 the dental overlay is gone: S23 must wait")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
