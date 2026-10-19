extends SceneTree
## godot --headless --path game -s tests/dental_tests.gd

const Dental = preload("res://scripts/core/dental.gd")
const Steadiness = preload("res://scripts/core/steadiness.gd")
const GameState = preload("res://scripts/core/game_state.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# Silas: three genuine matches prove it; distractors cost doubt, not the run
	var d := Dental.new("silas")
	ok(d.true_matches() == [14, 19, 30], "silas true matches %s" % [d.true_matches()])
	ok(d.flag(8) == "miss", "recent composite is not a match")
	ok(d.flag(27) == "miss", "Alan Pell's amalgam is not a match")
	ok(d.flag(5) == "miss", "empty tooth is not a match")
	ok(d.doubt == 3, "doubt counted")
	ok(not d.proven(), "not proven yet")
	ok(d.flag(19) == "match" and d.flag(19) == "again", "flag once")
	d.flag(30)
	ok(not d.proven(), "two is not three")
	d.flag(14)
	ok(d.proven(), "three marks prove it")
	ok(d.verdict().begins_with("Three of Casimir"), "verdict text")
	ok(d.flag(99) == "miss", "out-of-range tooth ignored")

	# the record has a tooth the patient lacks: it is not a match
	var d2 := Dental.new("silas")
	ok(d2.flag(3) == "miss", "record-only tooth is a miss")

	# Bea: two fillings
	var b := Dental.new("bea")
	b.flag(5); b.flag(12)
	ok(b.proven(), "Bea proven with two")

	# Delphine is human: a clean case; informative, never proves
	var p := Dental.new("delphine")
	ok(p.is_clean_case(), "Delphine has no matches")
	p.flag(30); p.flag(19)
	ok(not p.proven(), "cannot prove a human")
	ok(p.verdict().contains("exactly who she says"), "clean verdict")

	# Overlay + pins -> Seal S25 on the real board
	var g := GameState.new()
	g.board.add_evidence("LF-055"); g.board.add_evidence("LF-056")
	ok(g.board.block_reason("S25").begins_with("needs_pinned"), "S25 needs pinned evidence")
	g.board.pin("LF-055", "who"); g.board.pin("LF-056", "who")
	ok(g.board.can_test("S25"), "S25 testable on Day 1 with the dental overlay")
	ok(g.board.complete_test("S25", 1), "S25 sealed")

	# Steadiness: tracking the zone perfectly scores 3 stars; holding still does not
	var s := Steadiness.new(0.3)
	for i in 300:
		s.step(0.05, s.target(s.t + 0.05))
	ok(s.stars() == 3 and s.score() > 0.99, "perfect tracking")
	var idle := Steadiness.new(0.3)
	for i in 300:
		idle.step(0.05, Vector2(0.9, 0.9))
	ok(idle.stars() == 0, "never in the zone = 0 stars")
	var still := Steadiness.new(0.3)
	for i in 300:
		still.step(0.05, Vector2.ZERO)
	ok(still.score() > 0.1 and still.score() < 0.9, "holding still partly works (cozy)")
	var wide := Steadiness.new(0.3); wide.distraction = 1.0
	ok(wide.target(1.7).length() != Steadiness.new(0.3).target(1.7).length(), "distraction changes the drift")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
