extends SceneTree
## godot --headless --path game -s tests/town_game_tests.gd : the town sim as a game. Wake in someone, live the day, swap.

const TownGame = preload("res://scripts/sim/town_game.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Talk = preload("res://scripts/sim/talk.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var g := TownGame.new(5)
	var s: RefCounted = g.sim
	ok(g.host != "" and g.phase == "day" and s.day == 1 and s.clock == 0, "boots into a morning as somebody")
	ok(g.me().location == g.me().home, "you wake at home")
	# every resident can be a host: a briefing exists and reads sensibly
	var bad := 0
	for id in s.order:
		if id == "player":
			continue
		var b: Dictionary = Brief.make(s, id)
		var t := Brief.text(s, b)
		if t.length() < 40 or not t.contains(s.people[id].display) or b["plan"].is_empty():
			bad += 1
	ok(bad == 0, "all %d residents have a readable briefing (%d bad)" % [s.order.size() - 1, bad])
	# live a day
	var b0: Dictionary = g.brief()
	var work: String = g.me().work
	var due: bool = s.on_shift(g.me(), 9.0)
	var r: Dictionary
	if work != "" and work != g.me().home and due:
		r = g.go(work)
		ok(r["ok"], "walk to work")
		ok(g.me().location == work, "and you are there")
	r = g.do("relax", 1.0)
	ok(r["ok"] and s.clock >= 2, "an hour passes")
	r = g.do("sleep", 1.0)
	ok(not r["ok"] or g.me().location == g.me().home, "you can't sleep anywhere but home")
	# the people around
	var spot := ""
	for pl in ["pink_heron", "pageant_green", "rising_loaf", "low_water"]:
		g.go(pl)
		if not g.people_here().is_empty():
			spot = pl
			break
	if spot != "":
		var npc: String = g.people_here()[0]
		for topic in Talk.TOPICS:
			var tr: Dictionary = g.talk(npc, topic["id"])
			ok(tr.get("text", "") != "" or tr.get("ok", true) == false, "talk topic %s answers" % topic["id"])
			if s.day_over():
				break
	g.end_day()
	ok(g.phase == "night" and s.day_over(), "the day ends and it is night")
	var first: String = g.host
	var money_then: float = g.me().money
	var nid: String = g.dawn()
	ok(nid != first and g.host == nid and s.day == 2 and g.phase == "day" and s.clock == 0, "dawn: someone new, a new day, a morning")
	ok(g.me().location == g.me().home, "and you wake at home")
	ok(is_equal_approx(s.people[first].money, money_then) or s.people[first].money >= 0.0, "the last host keeps living their life")
	ok(g.lives_report().size() == 2 and g.lives_report()[0]["id"] == first, "the lives report remembers who you were")
	# 20 days as 20 different people
	var ids: Array = [first, nid]
	for d in 18:
		g.end_day()
		ids.append(g.dawn())
	var uniq: Dictionary = {}
	for id in ids:
		uniq[id] = true
	var first14: Dictionary = {}
	for id in ids.slice(0, 14):
		first14[id] = true
	ok(first14.size() == 14, "fourteen mornings, fourteen different people")
	ok(uniq.size() >= 17, "twenty mornings, almost all different people (%d unique)" % uniq.size())
	ok(g.lives_report().size() == uniq.size(), "the reckoning lists each person once")
	# STEER: unsettle someone calm, calm the leader: the ordering moves
	var g2 := TownGame.new(9)
	g2.end_day()
	var ex: Array = g2._recent()
	var rank: Array = g2.cause.ranking_open(g2.sim, ex, g2.days_since())
	var target: String = rank[10]["id"]
	g2.night_visit("unsettle", target)
	g2.night_visit("unsettle", target)
	var rank2: Array = g2.cause.ranking_open(g2.sim, ex, g2.days_since())
	var pos2 := 0
	for i in rank2.size():
		if rank2[i]["id"] == target:
			pos2 = i
	ok(pos2 < 10, "two unsettling visits lifted them from #11 to #%d" % (pos2 + 1))
	ok(g2.night_budget == 0 and not g2.night_visit("comfort", target)["ok"], "you only get two visits a night")
	# the same sim, different days: lives really do differ
	var sigs: Dictionary = {}
	var s3 := TownGame.new(3).sim
	s3.start_day()
	var trails: Dictionary = {}
	for t in 36:
		s3.step_tick(t)
		for id in s3.order.slice(30, 90):
			trails[id] = trails.get(id, "") + s3.people[id].location.substr(0, 2)
	for id in trails:
		sigs[trails[id]] = true
	ok(sigs.size() >= 45, "sixty residents, %d different days" % sigs.size())
	# talk differences: friend vs rival
	var s4 := TownGame.new(4).sim
	var a: RefCounted = s4.people[s4.order[40]]
	var c: RefCounted = s4.people[s4.order[41]]
	a.rel[c.id] = {"affinity": 90.0, "trust": 90.0}
	c.rel["x"] = {"affinity": 0.0, "trust": 0.0}
	var rival: RefCounted = s4.people[s4.order[42]]
	rival.rel[c.id] = {"affinity": -80.0, "trust": -80.0}
	var warm := 0; var cold := 0
	for k in 12:
		s4.clock = k
		if Talk.tier(s4, a, c.id, "chat") != "cold":
			warm += 1
		if Talk.tier(s4, rival, c.id, "chat") == "cold":
			cold += 1
	ok(warm >= 10 and cold >= 10, "friends warm up, rivals freeze (%d / %d of 12)" % [warm, cold])
	# decisions: quitting does not erase you in the sim; leaving town does
	var g5 := TownGame.new(6)
	var who: String = g5.host
	g5.act("quit_job")
	ok(not g5.me().employed, "quitting your job leaves you unemployed")
	g5.end_day(); g5.dawn()
	ok(g5.sim.alive(g5.sim.people[who]), "and you are still in town tomorrow")
	var g6 := TownGame.new(6)
	var who6: String = g6.host
	g6.act("leave_town")
	g6.end_day(); g6.dawn()
	ok(not g6.sim.alive(g6.sim.people[who6]), "leaving town takes you out of the town for good")
	ok(g6.lives_report()[0]["gone"], "and the reckoning says so")
	print("town_game_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
