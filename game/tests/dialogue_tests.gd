extends SceneTree
## godot --headless --path game -s tests/dialogue_tests.gd

const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
const Data = preload("res://scripts/core/data.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# structural: every convo is well-formed and every path ends
	var all: Dictionary = Data.load_json("convos/day01.json")
	for id in all:
		var nodes: Dictionary = all[id]["nodes"]
		ok(nodes.has(all[id]["start"]), "%s has a start" % id)
		var has_end := false
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if n.get("end", false):
				has_end = true
			for c in n.get("choices", []):
				ok(nodes.has(c["next"]), "%s/%s -> %s exists" % [id, nid, c["next"]])
			ok(n.get("end", false) or n.get("choices", []).size() > 0, "%s/%s is not a dead end" % [id, nid])
		ok(has_end, "%s can end" % id)

	# Silas, the bold route
	var g := GameState.new(true)
	var d := Dialogue.new()
	d.start(g, "day01.json", "silas")
	d.choose(1)   # out of character: "do I know you?"
	var risk: int = g.persona.self_risk(g.current_life()["style"])
	ok(g.suspicion.get_s("silas") == 25 + risk, "out-of-character raises suspicion, plus the cost of sounding like yourself (%d)" % risk)
	ok(g.notes.get_note("fidelity") == -10, "and costs fidelity")
	d.choose(0)   # ask who did it
	ok(g.board.evidence.has("LF-055"), "crown evidence found")
	d.choose(0)   # Rook
	ok(g.suspicion.get_s("silas") == 25 + risk + 10 + 30, "bold route raises suspicion to %d" % g.suspicion.get_s("silas"))
	ok(g.suspicion.get_s("silas") < 80, "still below the staged-test threshold of 80")
	ok(g.board.evidence.has("LF-056"), "overlay evidence found")
	ok(d.tells.has("hum"), "the hum tell registered")
	d.choose(0)
	ok(d.finished, "ended")
	ok(d.choose(0).is_empty(), "no choices after the end")

	# Silas, the safe route: nothing suspicious, but nothing learned
	var g2 := GameState.new(true)
	var d2 := Dialogue.new()
	d2.start(g2, "day01.json", "silas")
	d2.choose(0); d2.choose(1)
	ok(d2.finished and g2.suspicion.get_s("silas") == 0, "the quiet route is a valid, calm outcome")
	ok(g2.board.evidence.is_empty(), "and finds no evidence")

	# the safe route is never a hard fail, and a bad index is ignored
	var d3 := Dialogue.new()
	d3.start(GameState.new(true), "day01.json", "bea")
	d3.choose(99)
	ok(not d3.finished, "bad index ignored")

	# Cal's notebook gives evidence either way
	var g4 := GameState.new(true)
	var d4 := Dialogue.new()
	d4.start(g4, "day01.json", "cal")
	d4.choose(0); d4.choose(1)
	ok(g4.board.evidence.has("LF-015"), "notebook evidence")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
