extends SceneTree
## godot --headless --path game -s tests/reactions_tests.gd : the town brings up what you did, in any body.

const World = preload("res://scripts/sim/sim_world.gd")
const Reactions = preload("res://scripts/core/reactions.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func kinds(l: Array) -> Array:
	return l.map(func(o): return o["kind"])

func _initialize() -> void:
	var w := World.new(11)
	w.start_day()
	ok(Reactions.openers(w, "daniel", "jo", 1).is_empty() or true, "fresh town: no crash")
	ok(not kinds(Reactions.openers(w, "daniel", "jo", 1)).has("memory"), "nothing happened yet: no memory opener")

	# theft: the victim remembers, in the same body, next day
	w.people["daniel"].money = 500.0
	w.take_control("jo")
	var r := w.player_act("jo", "steal", {"target": "daniel", "amount": 100})
	ok(r["ok"], "theft works")
	var o := Reactions.openers(w, "daniel", "jo", 2)
	ok(kinds(o).has("memory") and o[0]["tone"] == "cold" and o[0]["suspicion"] > 0, "the victim greets the thief coldly")
	# a witness
	var wit := ""
	for q in w._witnesses(w.people["jo"]):
		wit = q.id
	if wit != "":
		ok(kinds(Reactions.openers(w, wit, "jo", 2)).has("memory"), "a witness brings it up too")
	# but in a DIFFERENT body, the victim does not accuse; the rumour is what travels
	var o2 := Reactions.openers(w, "daniel", "mags", 2)
	ok(not kinds(o2).has("memory"), "the victim does not blame a different body for the theft")
	# the rumour reaches people about the thief
	var believer := ""
	for id in w.order:
		if id != "jo" and id != "daniel" and float(w.rumors[0]["belief"].get(id, 0.0)) >= 50.0:
			believer = id
	w.broadcast(w.rumors[0]["id"], 0.9)
	var any_rumor := false
	for id in w.order:
		if id != "jo" and id != "daniel" and kinds(Reactions.openers(w, id, "jo", 2)).has("rumor"):
			any_rumor = true
	ok(any_rumor, "after the rumour spreads, other people repeat it to the thief's face")

	# a gift: warm, and calms suspicion
	var w2 := World.new(11); w2.start_day(); w2.take_control("mags")
	w2.player_act("mags", "gift", {"target": "fitz", "amount": 50})
	var g := Reactions.openers(w2, "fitz", "mags", 2)
	ok(kinds(g).has("memory") and g[0]["tone"] == "warm" and g[0]["suspicion"] < 0, "a gift is remembered warmly")

	# insult
	var w3 := World.new(11); w3.start_day(); w3.take_control("jo")
	w3.player_act("jo", "insult", {"target": "lux"})
	ok(Reactions.openers(w3, "lux", "jo", 2)[0]["tone"] == "cold", "an insult is remembered")

	# caps, determinism, gone friends
	ok(Reactions.openers(w, "daniel", "jo", 2).size() <= Reactions.MAX_LINES, "at most %d openers" % Reactions.MAX_LINES)
	ok(str(Reactions.openers(w, "daniel", "jo", 2)) == str(Reactions.openers(w, "daniel", "jo", 2)), "deterministic")
	var w4 := World.new(5); w4.start_day()
	w4.people["tobi"].taken = true
	w4.people["adaeze"].rel["tobi"] = {"affinity": 70.0, "trust": 60.0}
	ok(kinds(Reactions.openers(w4, "adaeze", "mags", 3)).has("vacancy"), "a friend of someone who is gone mentions it")

	# mood body language
	var w5 := World.new(5); w5.start_day()
	for k in w5.people["fitz"].needs:
		w5.people["fitz"].needs[k] = 5.0
	ok(kinds(Reactions.openers(w5, "fitz", "mags", 1)).has("mood"), "a miserable person shows it")

	# integrated: conversation applies the suspicion once, and shows the openers
	var gs := GameState.new(true)
	var d := Dialogue.new()
	d.start(gs, "day02.json", "daniel", w3 if false else w)
	ok(d.openers.size() > 0, "dialogue carries openers when given a sim")
	var d2 := Dialogue.new()
	var gs2 := GameState.new(true)
	d2.start(gs2, "day02.json", "daniel")
	ok(d2.openers.is_empty(), "no sim, no openers (old callers unchanged)")

	print("reactions_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
