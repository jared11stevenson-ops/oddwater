extends SceneTree
## godot --headless --path game -s tests/history_tests.gd : the town remembers where everyone was.

const World = preload("res://scripts/sim/sim_world.gd")
const TownGame = preload("res://scripts/sim/town_game.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var w := World.new(7, true)
	w.start_day()
	w.simulate_rest_of_day()
	ok(w.history.has(1) and w.history[1].size() == 36, "a full day of positions is recorded")
	var id: String = w.order[40]
	ok(w.where_was(id, 1, 0) == w.people[id].home or w.where_was(id, 1, 0) != "", "everyone was somewhere at 6am")
	# the record matches what the sim did
	var w2 := World.new(7, true)
	w2.start_day()
	var seen: Dictionary = {}
	for t in 36:
		w2.step_tick(t)
		seen[t] = w2.people[id].location
	var match_all := true
	for t in 36:
		if w2.where_was(id, 1, t) != seen[t]:
			match_all = false
	ok(match_all, "where_was agrees with where they really were, tick by tick")
	var lot: String = w2.where_was(id, 1, 20)
	ok(w2.who_was_at(lot, 1, 20).has(id), "who_was_at finds them there")
	# nights are at home unless the record says otherwise
	ok(w2.where_was(id, 1, 40) == w2.people[id].home, "after midnight people are in bed")
	w2.night[1] = {id: {"lot": "pink_heron", "from": 25.0, "to": 27.0}}
	ok(w2.where_was(id, 1, 38) == "pink_heron" and w2.where_was(id, 1, 42) == w2.people[id].home, "a night record moves someone for its hours only")
	# three days of memory
	for d in 5:
		w2.day = 2 + d
		w2.start_day()
		w2.simulate_rest_of_day()
	ok(not w2.history.has(1) and w2.history.has(6), "old days are forgotten")
	# death
	var victim: RefCounted = w2.people[w2.order[50]]
	victim.dead = true
	ok(not w2.alive(victim), "the dead are not among the living")
	# saves keep it all
	var g := TownGame.new(9)
	g.sim.simulate_rest_of_day() if false else null
	g.end_day()
	g.save("user://hist_save.json")
	var g2: RefCounted = TownGame.load_game("user://hist_save.json")
	ok(g2.sim.history.has(g.sim.day) and g2.sim.where_was(g.host, g.sim.day, 10) == g.sim.where_was(g.host, g.sim.day, 10), "history survives a save")
	victim.dead = true
	g.sim.people[g.sim.order[60]].dead = true
	g.save("user://hist_save.json")
	var g3: RefCounted = TownGame.load_game("user://hist_save.json")
	ok(g3.sim.people[g3.sim.order[60]].dead, "and so does death")
	TownGame.delete_save("user://hist_save.json")
	print("history_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
