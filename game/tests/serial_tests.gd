extends SceneTree
## godot --headless --path game -s tests/serial_tests.gd : serial killers: rare, harder, relentless, in the news, and a deadline.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Bot = preload("res://tests/case_bot.gd")
const Helpers = preload("res://tests/case_bot_helpers.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Prose = preload("res://scripts/detective/prose.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _night(g: RefCounted) -> void:
	g.end_day()
	g.dawn()

func _initialize() -> void:
	# --- rare
	var n := 0
	for s in 400:
		if Serial.rolls(s, "start"):
			n += 1
	ok(n > 0 and n <= 25, "serial killers are very rare (about 1 in 50): %d in 400 seeds" % n)
	var s1: Dictionary = Serial.begin(DetectiveGame.new(11).sim, 5, "a")
	var s2: Dictionary = Serial.begin(DetectiveGame.new(11).sim, 5, "a", [s1["signature"]])
	ok(s1["signature"] != s2["signature"] and s1["nick"] != s2["nick"], "every serial killer has a signature of their own")
	# --- the first case is harder
	var g := DetectiveGame.new(11, "", true)
	var s: Dictionary = g.serial
	var c: Dictionary = g._truth
	ok(Serial.active(s) and c.get("serial", false) and c["killer"] == s["killer"], "a serial killer is on the loose")
	ok(c["held_back"] == s["signature"] and (s["kills"] as Array).size() == 1, "the signature is the held-back detail; one kill so far")
	ok(not c["facts"].has("f_kn_saw") and not c["facts"].has("f_argument") and c["relatives"][c["killer"]].is_empty(), "no neighbour saw them go, no quarrel, no family to break")
	ok(c["clues"]["c_door"]["claims"][0]["predicate"] == "forced_entry" and not c["clues"]["c_desk"].get("thread", false) and not c["clues"].has("c_dropped"), "a forced window, a clean first scene, and the thread that links the dead hidden until the second body")
	ok(g.news().is_empty() and g.pressure() == 0.0, "no news until three")
	ok(c["clues"].has("c_unease") and c["clues"].has("c_diary") and not String(c["clues"]["c_unease"]["text"]).contains("{v}"), "every scene has its wrongness and the victim's last pages")
	g.det.skills["empathy"] = 5
	g.det.skills["observation"] = 5
	var st0: float = g.det.stress
	g.examine(c["scene"], "body")
	ok(g.det.has("c_unease") and g.det.stress >= st0 + 14.0, "the wrongness costs you: stress %d -> %d" % [int(st0), int(g.det.stress)])
	# --- the killer does not wait
	var victims := [c["victim"]]
	var sigs := {c["held_back"]: true}
	var guard := 0
	while (s["kills"] as Array).size() < 3 and guard < 12:
		_night(g)
		guard += 1
		if g._truth["victim"] != victims[-1]:
			victims.append(g._truth["victim"])
			sigs[g._truth["held_back"]] = true
	ok(victims.size() == 3 and sigs.size() == 1, "they keep killing, and always leave the same sign: %d victims" % victims.size())
	ok(g._truth["killer"] == c["killer"] and victims.all(func(v): return not g.sim.alive(g.sim.people[v])), "the same hand; the dead stay dead")
	ok(guard <= 8, "within a week they have taken three: %d nights" % guard)
	ok(int(s["third_day"]) >= 0 and not g.news().is_empty() and g.pressure() >= 20.0, "after three: the Courier prints it, the meter starts at %d" % int(g.pressure()))
	ok(String(g.objective()).contains(String(s["nick"])), "the objective names the killer the town has named")
	# --- pressure eats your reputation
	var rep0: int = g.det.reputation["town"]
	var sher0: int = g.det.reputation["sheriff"]
	var p0 := g.pressure()
	for i in 3:
		_night(g)
	ok(g.pressure() > p0, "the meter climbs: %d -> %d" % [int(p0), int(g.pressure())])
	ok(g.det.reputation["town"] < rep0, "the town loses faith: %d -> %d" % [rep0, g.det.reputation["town"]])
	# --- the deadline: the state police take over
	guard = 0
	while Serial.active(s) and guard < 20:
		_night(g)
		guard += 1
	ok(s["status"] == "failed" and g.det.reputation["sheriff"] <= sher0 - 30, "past the deadline the state police take the case: sheriff %d -> %d" % [sher0, g.det.reputation["sheriff"]])
	ok(g.news()[-1]["kind"] == "failed", "and the front page says so")
	# --- save and load keep it all
	g.save("user://serial_test.json")
	var l: RefCounted = DetectiveGame.load_detective("user://serial_test.json")
	ok(l != null and l.serial["status"] == "failed" and l.news().size() == g.news().size(), "a saved game remembers the killer and the paper")
	# --- catching them in time
	var g2 := DetectiveGame.new(11, "", true)
	var guard2 := 0
	while (g2.serial["kills"] as Array).size() < 3 and guard2 < 12:
		_night(g2)
		guard2 += 1
	var pr: float = g2.pressure()
	var town0: int = g2.det.reputation["town"]
	var bot = Bot.new(g2)
	var br: Dictionary = bot.solve()
	var brj: Dictionary = Helpers.judged(g2, br)
	ok(brj["verdict"] == "convicted", "the serial case is fair: a thorough detective can prove it (%s)" % brj["verdict"])
	var res: Dictionary = g2.accuse(br["accused"], br["motive"], br["method"])
	ok(g2.serial["status"] == "caught" and g2.pressure() == 0.0, "caught: the meter drops from %d to 0" % int(pr))
	ok(g2.det.reputation["town"] > town0 + 10, "and the town loves you for it")
	var k0: String = g2._truth["killer"]
	var stopped := true
	for i in 8:
		_night(g2)
		if g2._truth["killer"] == k0 and g2._truth["id"] != res.get("case_id", g2._truth["id"]) and not g2.solved():
			stopped = false
	ok(g2.sim.people[k0].taken or g2.sim.people[k0].jailed, "the killer is gone")
	ok(stopped and g2.serial.get("killer", "") != k0 or g2.serial["status"] == "caught", "no more murders by that hand")
	# --- the town grows two days after a solved case
	ok(g2.newcomers.size() >= 1, "a newcomer moved in after the case was solved: %d" % g2.newcomers.size())
	var nc: Dictionary = g2.newcomers[0]
	var np: RefCounted = g2.sim.people[nc["id"]]
	ok(g2.sim.order.has(nc["id"]) and g2.sim.alive(np) and np.home != "" and np.job != "" and np.hobby != "" and np.rel.size() >= 1, "with a home, a job, a hobby and a few ties: %s, %s" % [np.display, np.job])
	g2.save("user://grow_test.json")
	var l2: RefCounted = DetectiveGame.load_detective("user://grow_test.json")
	ok(l2 != null and l2.sim.people.has(nc["id"]) and l2.sim.people[nc["id"]].display == np.display, "a saved game brings the newcomer back")
	var no_nc := DetectiveGame.new(11, "", true)
	for i in 2:
		_night(no_nc)
	ok(no_nc.newcomers.is_empty(), "nobody moves in while a case is open")
	# --- a lazy detective does not stop it
	var g3 := DetectiveGame.new(11, "", true)
	for i in 9:
		_night(g3)
	ok((g3.serial["kills"] as Array).size() >= 3, "if you do nothing, the dead pile up: %d" % (g3.serial["kills"] as Array).size())
	# --- every forced-serial case is provably solvable, through the whole road: accuse -> arrest -> trial
	for sd in [110, 120, 101, 105, 115]:
		var gs := DetectiveGame.new(sd, "", true)
		var ks: String = gs._truth["killer"]
		var bs = Bot.new(gs)
		bs.solve()
		var missing: Array = gs._truth["clues"].keys().filter(func(id): return not gs.det.has(id))
		ok(missing.is_empty(), "seed %d: a thorough detective finds every clue (missing %s)" % [sd, str(missing)])
		var jr: Dictionary = Justice.trial(gs.sim, gs._truth, gs.det, ks)
		var jd: Dictionary = CaseOps.judge(gs.sim, gs._truth, gs.det, ks, gs._truth["motive"], gs._truth["method"])
		ok(jd["verdict"] == "convicted" and jr["confidence"] >= 70.0, "seed %d: judge and jury agree on a flawless notebook (%s, %d)" % [sd, jd["verdict"], int(jr["confidence"])])
		var rs: Dictionary = gs.accuse(ks, gs._truth["motive"], gs._truth["method"])
		ok(rs["verdict"] == "convicted" and rs.get("trial", {}).get("verdict", "") == "guilty" and gs.sim.people[ks].jailed, "seed %d: convicted at trial (%s, confidence %d)" % [sd, rs["verdict"], int(rs.get("trial", {}).get("confidence", -1))])
	# a thin notebook does not convict: judge and jury agree on that too
	var gt := DetectiveGame.new(120, "", true)
	var kt: String = gt._truth["killer"]
	var Cl = load("res://scripts/detective/claims.gd")
	gt.det.learn({"id": "thin", "title": "x", "text": "x", "kind": "testimony", "source": "", "day": 1, "claims": Cl.emit(gt._truth, [Cl.make("seen", kt, "carried_bundle", "", -1.0, "", 1.0), Cl.make("said", kt, "owns_matching_set", "", -1.0, "", 0.5), Cl.make("said", kt, "washed_evidence", "", -1.0, "", 0.5)], "", "x")})
	var jt: Dictionary = CaseOps.judge(gt.sim, gt._truth, gt.det, kt, gt._truth["motive"], gt._truth["method"])
	ok(jt["verdict"] != "convicted" and Justice.trial(gt.sim, gt._truth, gt.det, kt)["confidence"] < 70.0, "a thin case neither convicts on the judge's word nor at trial (%s)" % jt["verdict"])
	# --- ask "know": always a meaningful reply, from everyone
	var gk := DetectiveGame.new(110, "", true)
	var empty_know := 0
	for id in gk.sim.order:
		if id == "player" or not gk.sim.alive(gk.sim.people[id]):
			continue
		if String(gk.ask(id, "know")["text"]).strip_edges().length() < 12:
			empty_know += 1
	ok(empty_know == 0, "everyone answers 'what do you know': %d silent" % empty_know)
	# --- job names carry their article ("an events coordinator")
	var ga := DetectiveGame.new(11)
	ga._welcome_newcomer()
	var arr: String = ga._arrivals[-1]
	var nj: String = String(ga.newcomers[-1]["job"])
	ok(arr.contains(Prose.job_np(nj)) and not arr.contains(", a events") and not arr.contains(", a %s," % nj) or Prose.job_np(nj).begins_with("a "), "the arrival text uses the article helper: %s" % arr)
	print("serial_tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
