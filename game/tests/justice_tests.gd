extends SceneTree
## godot --headless --path game -s tests/justice_tests.gd : arrest, interrogation, trial, jail, appeal.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# --- a thorough case: arrest, interview, true confession, trial, jail
	var g := DetectiveGame.new(11)
	var k: String = g.case["killer"]
	ok(not g.arrest(k)["ok"], "no arrest on a hunch")
	var bot = Bot.new(g.sim, g.case, g.det)
	bot.solve()
	var a: Dictionary = g.arrest(k)
	ok(a["ok"] and g.court["custody"] == k and g.court["trial_day"] == g.sim.day + 3, "with proof, an arrest: %s" % a["text"])
	var got := false
	for i in 8:
		var r: Dictionary = g.interrogate("evidence")
		if g.det.has("confession_" + k):
			got = true
			break
	ok(got and g.det.known["confession_" + k].get("has_detail", false), "the weight of evidence breaks the killer: a true confession with the held-back detail")
	ok(not g.trial_ready(), "the trial is not until its day")
	g.sim.day = int(g.court["trial_day"])
	var t: Dictionary = g.run_trial()
	ok(t["verdict"] == "guilty" and not t["wrongful"], "a thorough case convicts: confidence %d" % int(t["confidence"]))
	ok(g.sim.people[k].jailed and not g.sim.alive(g.sim.people[k]) and g.jail.size() == 1 and g.solved(), "the killer is in the jail, the case is closed")
	# --- the jail
	var inm: Dictionary = g.jail[0]
	var vr: Dictionary = g.visit(k, "crime")
	ok(vr["text"].contains("won't say") or vr["text"].contains("will not say"), "a stranger gets nothing: %s" % vr["text"].substr(0, 40))
	for i in 3:
		g.visit(k, "talk")
	ok(g.visit(k, "crime")["text"].contains(g.case["held_back"]), "with rapport the inmate tells you the detail and the why")
	var lore0: int = g.det.order.filter(func(e): return String(e).begins_with("lore_")).size()
	g.visit(k, "town")
	ok(g.det.order.filter(func(e): return String(e).begins_with("lore_")).size() == lore0 + 1, "and a piece of the town's older secret")
	ok(g.visit(k, "profile")["text"].contains(inm["type"]), "each inmate is a type to study")
	g.save("user://jail_save.json")
	var g2: RefCounted = DetectiveGame.load_detective("user://jail_save.json")
	ok(g2.jail.size() == 1 and g2.sim.people[k].jailed and g2.inmate(k)["rapport"] > 20.0, "the Gallery survives a save")
	DetectiveGame.delete_save("user://jail_save.json")
	# --- pressure on an innocent produces a false confession, and the trial doubts it
	var h := DetectiveGame.new(12)
	var innocent: String = h.suspects().filter(func(x): return x != h.case["killer"])[0]
	var hb = Bot.new(h.sim, h.case, h.det)
	hb.examine_scene()
	h.det.learn({"id": "x1", "title": "x", "text": "x", "kind": "testimony", "source": "", "supports": [{"cat": "opportunity", "about": innocent, "strength": 2}, {"cat": "motive", "about": innocent, "strength": 2}], "day": 1})
	ok(h.arrest(innocent)["ok"], "an innocent person can be arrested on enough circumstance")
	var false_conf := false
	for i in 6:
		h.interrogate("pressure")
		if h.det.has("confession_" + innocent):
			false_conf = true
			break
	ok(false_conf and h.det.known["confession_" + innocent].get("unreliable", false), "hours of pressure on an innocent person produce a false confession")
	h.sim.day = int(h.court["trial_day"])
	var t2: Dictionary = h.run_trial()
	ok(t2["attacks"].any(func(x): return x["text"].contains("nothing only the killer would know")), "the defence takes the confession apart")
	ok(t2["verdict"] != "guilty" or t2["wrongful"], "it does not convict the right way (verdict %s, %d)" % [t2["verdict"], int(t2["confidence"])])
	# --- a wrongful conviction in jail can be appealed once you can prove the truth
	var w := DetectiveGame.new(13)
	var inn: String = w.suspects().filter(func(x): return x != w.case["killer"])[0]
	w.jail.append({"id": inn, "case": w.case["id"], "guilty": false, "sentence": 25, "type": "remorseful", "rapport": 0.0, "told": [], "day": 1, "freed": false})
	w.sim.people[inn].jailed = true
	ok(not w.appeal(inn)["ok"], "no appeal without proof of who really did it")
	Bot.new(w.sim, w.case, w.det).solve()
	var ap: Dictionary = w.appeal(inn)
	ok(ap["ok"] and not w.sim.people[inn].jailed and w.jail.is_empty(), "with proof, the innocent are freed: %s" % ap["text"].substr(0, 40))
	# --- not guilty frees a guilty person, and they know it
	var n := DetectiveGame.new(14)
	n.court = {"custody": n.case["killer"], "trial_day": 1, "sess": {}}
	var t3: Dictionary = n.run_trial()
	ok(t3["verdict"] == "not guilty" and n.case.get("alerted", false) and not n.sim.people[n.case["killer"]].jailed, "a case with nothing in it ends in acquittal, and the killer is alerted")
	print("justice_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
