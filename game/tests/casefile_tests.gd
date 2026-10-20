extends SceneTree
## godot --headless --path game -s tests/casefile_tests.gd : the Pattern grid and the proof of the Rule.

const Casefile = preload("res://scripts/core/casefile.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const World = preload("res://scripts/sim/sim_world.gd")
const Cause = preload("res://scripts/sim/cause.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func name_of(id: String) -> String:
	return id.capitalize()

func _initialize() -> void:
	var c := Casefile.new()
	ok(not c.rule_proven and c.hits() == 0, "starts unproven")
	ok(c.grid_text(name_of).contains("Nobody has been taken"), "empty grid says so")
	# night 1: on the edge, guessed right
	c.open_night([{"id": "mags"}, {"id": "jo"}])
	c.predict("mags")
	var r := c.resolve(1, "mags")
	ok(r["hit"] and r["earned"] and c.hits() == 1 and not r["proved_now"], "first earned hit")
	# night 2: right, but about a calm person: luck, not proof
	c.open_night([{"id": "tobi"}])
	c.predict("jo")
	r = c.resolve(2, "jo")
	ok(r["hit"] and not r["earned"] and c.hits() == 1, "a lucky hit on a calm person does not count")
	# night 3: wrong
	c.open_night([{"id": "tobi"}, {"id": "delphine"}])
	c.predict("tobi")
	r = c.resolve(3, "delphine")
	ok(not r["hit"] and c.hits() == 1, "a miss counts for nothing")
	# night 4: no guess
	c.open_night([{"id": "vern"}])
	r = c.resolve(4, "vern")
	ok(not r["had_guess"] and c.predictions.size() == 3, "no guess, no prediction logged")
	# night 5: second earned hit proves the Rule
	c.open_night([{"id": "gus"}])
	c.predict("gus")
	r = c.resolve(5, "gus")
	ok(r["proved_now"] and c.rule_proven, "second earned hit proves the Rule")
	c.open_night([{"id": "x"}]); c.predict("x")
	ok(not c.resolve(6, "x")["proved_now"], "it only proves once")
	ok(c.log.size() == 6 and c.log[0]["edge"] and not c.log[1]["edge"], "the grid logs who was on the edge")
	# facts
	c.found_trace("mags"); c.saw_ribbon("vern")
	var rows := c.rows(name_of)
	ok(rows[0]["trace"].contains("found") and rows[3]["ribbon"] == "ribbon seen" and rows[1]["trace"] == "not looked for", "traces and ribbons show in the grid")
	ok(c.grid_text(name_of).contains("THE RULE IS PROVEN"), "the grid announces the proof")
	# save / load
	var c2 := Casefile.from_dict(c.to_dict())
	ok(c2.rule_proven and c2.log.size() == 6 and c2.traces.has("mags") and c2.hits() == c.hits(), "round-trips through a save")
	# forecast only after proof, and it names the Cause's real order
	var w := World.new(3); w.start_day()
	var cause := Cause.new()
	var elig := ["mags", "jo", "tobi", "delphine", "vern"]
	var fresh := Casefile.new()
	ok(fresh.forecast(cause, w, elig, name_of).is_empty(), "no forecast before the Rule is proven")
	ok(c.forecast(cause, w, elig, name_of).size() == 3, "three names after")
	ok(c.forecast(cause, w, elig, name_of)[0] == name_of.call(cause.pick(w, elig)), "and the first is who the Cause would pick")
	# game state integration
	var gs := GameState.new(true)
	gs.casefile.found_trace("mags")
	var gs2 := GameState.new(true)
	gs2.load_dict(gs.to_dict())
	ok(gs2.casefile.traces.has("mags"), "game state saves the case file")
	print("casefile_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
