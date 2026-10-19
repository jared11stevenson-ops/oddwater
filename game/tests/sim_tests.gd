extends SceneTree
## godot --headless --path game -s tests/sim_tests.gd : the living town.

const World = preload("res://scripts/sim/sim_world.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func snapshot(w: RefCounted) -> String:
	var s := ""
	for id in w.order:
		var p: RefCounted = w.people[id]
		s += "%s:%s:%s:%.1f:%.1f;" % [id, p.location, p.activity, p.money, p.mood()]
	return s

func _initialize() -> void:
	# --- data
	var w := World.new(7)
	ok(w.people.size() == 29, "29 simulated people incl. the player (%d)" % w.people.size())
	var town = load("res://scripts/core/town_layout.gd").new()
	var missing := []
	for id in w.order:
		var p: RefCounted = w.people[id]
		for loc in [p.home, p.work]:
			if loc != "" and not town.by_id.has(loc):
				missing.append(loc)
	ok(missing.is_empty(), "every home and workplace exists on the town map: %s" % [missing])
	for loc in w.HAUNTS + ["hardware", "post_office", "chapel"]:
		ok(town.by_id.has(loc), "haunt %s exists" % loc)
	# --- determinism
	var a := World.new(7); a.start_day(); a.simulate_rest_of_day()
	var b := World.new(7); b.start_day(); b.simulate_rest_of_day()
	var c := World.new(8); c.start_day(); c.simulate_rest_of_day()
	ok(snapshot(a) == snapshot(b), "same seed, same town")
	ok(snapshot(a) != snapshot(c), "different seed, different day")
	# --- routines: the Mayor is at Town Hall at 10:00, asleep at 05:00 equivalents
	var m := World.new(7); m.start_day()
	var seen_work := false
	var t10 := int((10.0 - m.tuning["day_start_hour"]) / m.tuning["tick_hours"])
	m.step_tick(t10 - 2); m.step_tick(t10 - 1); m.step_tick(t10)
	for id in ["delphine", "mags", "oren"]:
		var p: RefCounted = m.people[id]
		ok(p.activity in ["work", "eat"] and (p.activity != "work" or p.location == p.work), "%s is working (or eating) at 10:00: %s at %s" % [id, p.activity, p.location])
	ok(m.people["harlan"].activity != "work", "the retired don't work")
	# --- needs
	var n := World.new(7); n.start_day(); n.simulate_rest_of_day()
	var worked := 0
	var fed := 0
	for id in n.order:
		var p: RefCounted = n.people[id]
		ok(float(p.needs["energy"]) >= 0 and float(p.needs["energy"]) <= 100 and float(p.needs["restless"]) <= 100, "%s needs in range" % id)
		worked += 1 if p.last_activity != "" else 0
		fed += 1 if float(p.needs["hunger"]) > 5.0 else 0
	ok(fed >= 20, "most people eat during the day (%d of 28 not starving)" % fed)
	# --- restlessness: the Thin Weeks make it climb faster
	var thin := World.new(7); thin.start_day(); thin.simulate_rest_of_day()
	var calm := World.new(7); calm.thin_weeks = false; calm.start_day(); calm.simulate_rest_of_day()
	ok(thin.people["mags"].needs["restless"] > calm.people["mags"].needs["restless"], "restlessness climbs faster in the Thin Weeks")
	ok(thin.decision_pressure("mags") > 0.0, "decision pressure is readable")
	# --- relationships move with time spent together
	var rel0: float = thin.people["jo"].affinity("lux")
	var long := World.new(7)
	for d in 5:
		long.start_day(); long.simulate_rest_of_day(); long.slack()
	ok(long.people["jo"].affinity("lux") != rel0 or long.people["bea"].affinity("billie") != 80.0, "relationships drift over days")
	# --- the player takes over Mags and ruins her day
	var r := World.new(7); r.start_day()
	r.take_control("mags")
	var steal := r.player_act("mags", "steal", {"target": "delphine", "amount": 500})
	ok(steal["ok"] and r.people["mags"].money == 2400.0 + 500.0 and r.people["delphine"].money == 3200.0 - 500.0, "stealing moves money")
	ok(r.people["delphine"].trust("mags") < 30.0, "the victim stops trusting her")
	ok(r.rumors.size() == 1 and r.rumors[0]["truth"], "a true rumour about Mags starts")
	r.release_control({"nerve": 40, "warmth": -30})
	r.simulate_rest_of_day()
	var g := r.gazette()
	var l := r.ledger()
	r.slack()
	for i in 3:
		r.start_day(); r.simulate_rest_of_day(); r.slack()
	ok(r.believers(1) >= 3, "after four days the town hears it (%d believers)" % r.believers(1))
	ok(r.people["mags"].trait_of("bold") > 0.6, "boldness hardens into the Remnant")
	# --- the Mayor is quoted in the Gazette as 'a misunderstanding'
	ok(g.any(func(s): return s.contains("misunderstanding")) and l.any(func(s): return s.contains("robbed")), "the Gazette softens what the ledger records")
	# --- a Decision strikes the Remnant at the Slack
	var d := World.new(7); d.start_day()
	d.take_control("jo")
	var dec := d.player_act("jo", "quit_job")
	ok(dec["decision"] and d.pending.get("jo", "") == "struck", "quitting is a Decision: the Remnant will be Struck")
	ok(not d.people["jo"].employed, "and Jo has no job")
	d.release_control()
	ok(not d.people["jo"].struck, "not gone until 4:12")
	var gone := d.slack()
	ok(gone == ["jo"] and d.people["jo"].struck and d.day == 2, "struck at the Slack")
	ok(d.gazette().any(func(s): return s.contains("relocated")), "the Gazette says he has relocated")
	d.start_day(); d.simulate_rest_of_day()
	ok(d.people["jo"].location == "", "a Struck person is gone from the town")
	# --- ordinary changes are not Decisions
	var o := World.new(7); o.start_day(); o.take_control("billie")
	o.player_act("billie", "gift", {"target": "bea", "amount": 100})
	o.player_act("billie", "work", {"hours": 6})
	o.release_control()
	ok(o.pending.is_empty(), "gifts and work do not trigger a Strike")
	ok(o.people["bea"].affinity("billie") > 80.0, "the gift warmed Bea")
	# --- rumours are propaganda: a lie seeded and broadcast becomes belief
	var p2 := World.new(7); p2.start_day()
	var lie := p2.seed_rumor("bea", "Bea Lindgren is the one taking people.", false, "dolores", 4)
	ok(p2.believers(lie["id"]) == 1, "starts with one believer")
	p2.broadcast(lie["id"], 0.75)
	ok(p2.believers(lie["id"]) >= 27, "a broadcast makes it the town's truth (%d)" % p2.believers(lie["id"]))
	p2.simulate_rest_of_day()
	var ctrl := World.new(7); ctrl.start_day(); ctrl.simulate_rest_of_day()
	ok(p2.people["hank"].affinity("bea") < ctrl.people["hank"].affinity("bea"), "and Hank's love for Bea cools compared with a town where it was never said (%.1f vs %.1f)" % [p2.people["hank"].affinity("bea"), ctrl.people["hank"].affinity("bea")])
	# --- save / load
	var s := World.new(7); s.start_day(); s.simulate_rest_of_day()
	var saved := s.to_dict()
	var s2 := World.new(7); s2.load_dict(saved)
	ok(s2.people["mags"].money == s.people["mags"].money and s2.day == s.day, "round-trips")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
