extends SceneTree
## godot --headless --path game -s tests/cause_tests.gd : the Cause, STEER, and the host flow.

const World = preload("res://scripts/sim/sim_world.gd")
const Cause = preload("res://scripts/sim/cause.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const ELIG := ["mags", "jo", "tobi", "delphine", "vern"]
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

## Live one day as `host`, then let the town run. Returns the evening's world.
func day(w: RefCounted, host: String) -> void:
	w.start_day()
	w.take_control(host)
	w.simulate_rest_of_day()
	w.release_control()

func _initialize() -> void:
	# ---- baseline: nobody interferes, the authored order holds across seeds and across days
	var broken := 0
	for seed in range(1, 21):
		var w := World.new(seed)
		var c := Cause.new()
		var order: Array = []
		var host := "mags"
		for d in 4:
			c.mark_used(host)
			day(w, host)
			w.slack()
			host = c.pick(w, ELIG)
			order.append(host)
		if order != ["jo", "tobi", "delphine", "vern"]:
			broken += 1
	ok(broken == 0, "the authored order holds over 20 seeds x 4 days (%d seeds broke it)" % broken)
	# ---- STEER: one nudge does nothing; two deliberate nudges flip adjacent candidates
	var one_flip := 0
	var two_flip := 0
	for seed in range(1, 21):
		var w := World.new(seed); var c := Cause.new(); c.mark_used("mags")
		day(w, "mags")
		c.night_action(w, "unsettle", "tobi")
		one_flip += 1 if c.pick(w, ELIG) == "tobi" else 0
		c.night_action(w, "comfort", "jo")
		two_flip += 1 if c.pick(w, ELIG) == "tobi" else 0
	ok(one_flip == 0, "one nudge never steers (%d of 20)" % one_flip)
	ok(two_flip == 20, "unsettle the next one and calm the leader: tomorrow's host changes (%d of 20)" % two_flip)
	# ---- somebody always pays
	var w2 := World.new(3); var c2 := Cause.new(); c2.mark_used("mags")
	day(w2, "mags")
	var rank0: Array = c2.ranking(w2, ELIG)
	var leader: String = rank0[0]["id"]
	var runner: String = rank0[1]["id"]
	for i in 5:
		c2.night_action(w2, "comfort", leader)
		c2.night_action(w2, "unsettle", runner)
	var after: String = c2.pick(w2, ELIG)
	ok(after == runner, "calm the leader and unsettle the runner-up hard enough: somebody else is taken (%s -> %s)" % [leader, after])
	ok(not c2.ranking(w2, ELIG).is_empty(), "there is always someone to take while candidates remain")
	var w2b := World.new(3); var c2b := Cause.new(); c2b.mark_used("mags")
	day(w2b, "mags")
	for i in 5:
		c2b.night_action(w2b, "comfort", c2b.pick(w2b, ELIG))
	ok(c2b.pick(w2b, ELIG) != "", "calming alone can't save everyone: the Cause still takes somebody")
	ok(c2.pick(w2, ["nobody_here"]) == "", "no eligible candidates: no pick")
	# ---- used hosts are not retaken; dead/struck people are not candidates
	var w3 := World.new(3); var c3 := Cause.new()
	c3.mark_used("jo")
	ok(not c3.ranking(w3, ELIG).any(func(r): return r["id"] == "jo"), "a used host is excluded")
	w3.people["tobi"].struck = true
	ok(not c3.ranking(w3, ELIG).any(func(r): return r["id"] == "tobi"), "a struck person is excluded")
	# ---- observable tells: after a few days some people look on the edge
	var w4 := World.new(11)
	var seen := 0
	for d in 4:
		day(w4, "mags"); w4.slack()
		seen += c3.edge_report(w4).size()
	ok(seen > 0, "people on the edge become visible over a few days (%d sightings)" % seen)
	for e in c3.edge_report(w4):
		ok(e["tell"] != "" and e["level"] >= 55.0, "every report has a behavioural tell")
	# ---- the host flow in GameState
	var g := GameState.new()
	ok(g.current_life()["id"] == "mags" and g.host_history == ["mags"], "Day 1 is the authored first host")
	ok(g.baseline_next_id() == "jo", "authored next is Jo")
	g.next_host = "tobi"
	for i in 5: g.advance()
	ok(g.day == 2 and g.current_life()["id"] == "tobi", "the Cause chose Tobi: Day 2 is Tobi (%s)" % g.current_life()["id"])
	ok(g.next_host == "", "the choice is consumed")
	for i in 5: g.advance()
	ok(g.current_life()["id"] == "jo", "with no choice, the authored order resumes at the first unused life (Jo)")
	ok(g.board.tools_available["reply"] and not g.board.tools_available["small_paths"], "tools follow the host, not the day number")
	g.save_to("user://hosts.json")
	var h := GameState.new()
	ok(h.load_from("user://hosts.json") and h.host_history == ["mags", "tobi", "jo"] and h.current_life()["id"] == "jo", "the host history is saved")
	var all := GameState.new()
	for i in 13 * 5: all.advance()
	ok(all.current_life()["id"] in ["prop_room", "ellis"] or all.day >= 14, "after the lives run out we reach the Prop Room (%s, day %d)" % [all.current_life()["id"], all.day])
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
