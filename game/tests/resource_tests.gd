extends SceneTree
## godot --headless --path game -s tests/resource_tests.gd : scarcity and procedure. Warrants, lab slots, kit uses and favours are limited per case and
## replenish slowly; the claims-only bot still solves with margin; stakeouts use the real sim and cost something; informants may be wrong; a plea can
## close a case, or jail the wrong person; the numbers are written out so the budgets can be read.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const Resources = preload("res://scripts/detective/resources.gd")
const Stakeout = preload("res://scripts/detective/stakeout.gd")
const Informants = preload("res://scripts/detective/informants.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Lib = preload("res://tests/content_lib.gd")

var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	# ---------------------------------------------------------------- the numbers
	var d := Detective.new()
	Resources.ensure(d)
	var caps: Dictionary = Resources.caps(d)
	ok(int(d.res["warrants"]) == 2 and int(d.res["kit"]) == 20 and int(d.res["favours"]) == 3 and int(d.res["hunches"]) == 2 and Resources.lab_slots(d) == 3, "a first-level detective starts with 2 warrants, 3 lab slots a day, 20 kit uses, 3 favours and 2 hunches")
	d.level = 5
	d.rank = "Deputy"
	var cd: Dictionary = Resources.caps(d)
	ok(int(cd["warrants"]) == 2 and Resources.lab_slots(d) == 3 and int(cd["kit"]) == 20, "a demoted deputy has less than a detective of the same level (%s)" % cd)
	d.rank = "Detective"
	ok(int(Resources.caps(d)["warrants"]) == 3 and Resources.lab_slots(d) == 4 and int(Resources.caps(d)["kit"]) == 24, "rank and level raise the caps")
	d.res["warrants"] = 0
	Resources.dawn(d, 4)
	ok(int(d.res["warrants"]) == 1, "a warrant comes back every fourth day")
	Resources.dawn(d, 5)
	Resources.dawn(d, 6)
	ok(int(d.res["warrants"]) == 1, "and not in between")
	d.res["kit"] = 3
	Resources.dawn(d, 7)
	ok(int(d.res["kit"]) == 4, "the kit is restocked one use a day")
	Resources.new_case(d, 9)
	ok(int(d.res["warrants"]) == int(Resources.caps(d)["warrants"]) and int(d.res["kit"]) == int(Resources.caps(d)["kit"]), "a new case refills warrants and kit; favours carry over")

	# ---------------------------------------------------------------- the actions spend them
	var g: RefCounted = DetectiveGame.new(2)
	var k: String = String(g._truth["killer"])
	var sc: String = g.scene_lot()
	g.me().location = sc
	var kit0: int = int(g.det.res.get("kit", 20)) if not g.det.res.is_empty() else 20
	Resources.ensure(g.det)
	kit0 = int(g.det.res["kit"])
	g.dust(sc, "door")
	ok(int(g.det.res["kit"]) == kit0 - 1, "dusting a new surface spends a kit use")
	g.dust(sc, "door")
	ok(int(g.det.res["kit"]) == kit0 - 1, "dusting the same surface again does not")
	var someone: String = g.persons_of_interest()[0]
	g.det.warrants.clear()
	g.take_sample(g.case["victim"])
	ok(int(g.det.res["kit"]) == kit0 - 2, "taking prints spends a kit use")
	g.take_sample(g.case["victim"])
	ok(int(g.det.res["kit"]) == kit0 - 2, "but not twice for the same person")
	g.det.res["kit"] = 0
	var empty: Dictionary = g.dust(sc, "desk")
	ok(String(empty.get("blocked", "")) == "kit" and String(empty["text"]).contains("kit is empty"), "an empty kit stops the dusting")
	ok(String(g.take_sample(someone).get("blocked", "")) == "kit", "and the printing")
	# lab slots
	g.examine(sc, "body")
	var lab_ids: Array = []
	for eid in g.det.order:
		if g.det.known[eid].get("lab", false):
			lab_ids.append(eid)
	g.det.lab.clear()
	g.det.lab_done.clear()
	for i in 4:                      # make four samples out of the ones the case gives (the slots are what is being counted)
		var fake := {"id": "lab_t%d" % i, "title": "Sample %d" % i, "text": "x", "kind": "physical", "source": sc, "lab": true, "day": 1, "claims": [{"cid": "kz%d" % i, "kind": "found", "subject": "", "predicate": "observation", "place": sc, "time": -1.0, "until": -1.0, "item": "", "certainty": 1.0, "source": sc, "text": "x"}]}
		g.det.learn(fake)
		g._truth["clues"]["lab_t%d" % i] = {"id": "lab_t%d" % i, "lab": true, "lot": sc, "title": "x", "text": "x", "spot": "body"}
		lab_ids.append("lab_t%d" % i)
	var sent := 0
	var blocked := 0
	for i in 4:
		var rl: Dictionary = g.submit_lab("lab_t%d" % i)
		if String(rl.get("blocked", "")) == "lab":
			blocked += 1
		elif g.det.lab.any(func(l): return l["clue"] == "lab_t%d" % i):
			sent += 1
	ok(sent == 3 and blocked == 1, "the lab takes three jobs a day and no more (%d sent, %d turned away)" % [sent, blocked])
	var fav0: int = int(g.det.res["favours"])
	var rush: Dictionary = g.submit_lab("lab_t3", true)
	ok(g.det.lab.any(func(l): return l["clue"] == "lab_t3") and int(g.det.res["favours"]) == fav0 - 1, "a favour gets the technician to stay late")
	ok(Resources.lab_free(g.det, int(g.sim.day) + 1) == 3, "the slots are fresh the next morning")
	# warrants
	var wtarget := ""
	for p in g.persons_of_interest():
		wtarget = p
	g.det.res["warrants"] = 0
	var wr: Dictionary = g.warrant(wtarget)
	ok(String(wr.get("blocked", "")) == "warrants" and not g.det.warrants.get(wtarget, false), "with no warrants left the judge will not sign")
	g.det.res["warrants"] = 1
	var wr2: Dictionary = g.warrant(wtarget)          # not enough in the notebook: refused, and nothing is spent
	ok(not wr2["ok"] and int(g.det.res["warrants"]) == 1, "a refused request costs time, not a warrant")
	g.det.learn({"id": "w_ev", "title": "x", "text": "x", "kind": "testimony", "source": "", "day": 1, "claims": [
		{"cid": "kw1", "kind": "seen", "subject": wtarget, "predicate": "seen_going_out", "place": "", "time": 25.0, "until": 26.0, "item": "", "certainty": 1.0, "source": "", "text": "x"},
		{"cid": "kw2", "kind": "found", "subject": wtarget, "predicate": "weapon_in_home", "place": "", "time": -1.0, "until": -1.0, "item": "", "certainty": 1.0, "source": "", "text": "x"}]})
	var wr3: Dictionary = g.warrant(wtarget)
	ok(wr3["ok"] and int(g.det.res["warrants"]) == 0, "a granted warrant is spent")

	# ---------------------------------------------------------------- the bot, within budget
	var worst_kit := 99
	var worst_wr := 99
	var worst_lab := 99
	var n_ok := 0
	for spec in [[1, false], [3, false], [110, true], [105, true]]:
		var gb: RefCounted = DetectiveGame.new(int(spec[0]), "", bool(spec[1]))
		var bot = Bot.new(gb)
		var plan: Dictionary = bot.solve()
		var kb: String = String(gb._truth["killer"])
		var res: Dictionary = gb.accuse(plan["accused"], plan["motive"], plan["method"])
		if plan["accused"] == kb and res["verdict"] == "convicted":
			n_ok += 1
		worst_kit = mini(worst_kit, int(gb.det.res["kit"]))
		worst_wr = mini(worst_wr, int(gb.det.res["warrants"]))
		worst_lab = mini(worst_lab, Resources.lab_free(gb.det, int(gb.sim.day) - 1))
	ok(n_ok == 4, "the claims-only bot still solves ordinary and serial seeds under the budgets (%d of 4)" % n_ok)
	print("  budget margins after a full solve: kit left %d of 20 (bot reserves 5), warrants left %d of 2 (+ the rest unspent), lab slots used at most %d of 3" % [worst_kit, worst_wr, 3 - worst_lab])
	ok(worst_kit >= 3, "the evidence kit leaves margin (%d uses spare)" % worst_kit)
	ok(worst_wr >= 0, "warrants are enough for the houses the bot tries")

	# ---------------------------------------------------------------- stakeouts
	var gs: RefCounted = DetectiveGame.new(3)
	var tgt: String = gs.persons_of_interest()[0]
	var tlot: String = String(gs.sim.people[tgt].home)
	var clock0: int = gs.sim.clock
	var stress0: float = gs.det.stress
	var cnt0: int = gs.det.order.size()
	var res_s: Dictionary = gs.stakeout(tlot, 2)
	ok(res_s["ok"] and gs.sim.clock >= clock0 + 4, "a stakeout runs the real town clock forward (%d -> %d)" % [clock0, gs.sim.clock])
	ok(gs.det.stress > stress0, "and it wears on you")
	ok(gs.det.order.size() > cnt0 and (res_s["learned"] as Array).size() == 1, "the watch is a notebook entry")
	var e: Dictionary = res_s["learned"][0]
	ok((e["claims"] as Array).size() >= 1 and (e["claims"] as Array).all(func(c): return String(c["kind"]) in ["seen", "heard", "found", "recorded", "said"] and c.has("cid") and not c.has("_truth_tag")), "its claims are structured and carry no private tag")
	ok(Lib.problems(String(e["text"])).is_empty(), "its text is clean: %s" % [Lib.problems(String(e["text"]))])
	var gs2: RefCounted = DetectiveGame.new(3)
	var rs2: Dictionary = gs2.stakeout(tlot, 2)
	ok(String(rs2["text"]) == String(res_s["text"]), "the same seed watches the same street the same way")
	# what you see really happened: every named arrival was on that lot at that moment
	var real := true
	for cl in e["claims"]:
		if String(cl["predicate"]) in ["arrived_at", "left_from"] and String(cl["subject"]) != "" and gs._truth["claim_tags"].get(cl["cid"], "true") == "true":
			real = real and gs.sim.people.has(String(cl["subject"]))
	ok(real, "named sightings are of real residents")
	var late: RefCounted = DetectiveGame.new(3)
	late.sim.clock = 34
	var rl2: Dictionary = late.stakeout(tlot, 4)
	ok(not rl2["ok"] or int(rl2["hours"]) <= 1, "the day's end limits a watch (%s)" % rl2.get("hours", 0))
	var gk: RefCounted = DetectiveGame.new(3)
	var kk: String = String(gk._truth["killer"])
	var kh: String = String(gk.sim.people[kk].home)
	Stakeout._tip(gk, gk._truth, kh, kk, kk)
	ok(gk._truth.get("alerted", false) and int(gk._truth.get("killer_alert", 0)) >= 1, "being spotted by the killer alerts them")
	ok(gk._truth["clues"].values().any(func(c): return c.get("gone", false)), "and they clear the house of what you have not yet found")
	var gq: RefCounted = DetectiveGame.new(3)
	var bystander := ""
	for p in gq.sim.order:
		if p != "player" and p != String(gq._truth["killer"]) and gq.sim.alive(gq.sim.people[p]) and gq.sim.people[p].group == "adult":
			bystander = p
			break
	var aff: float = gq.sim.people[bystander].affinity("player")
	Stakeout._tip(gq, gq._truth, String(gq.sim.people[bystander].home), bystander, bystander)
	ok(gq.sim.people[bystander].affinity("player") < aff and not gq._truth.get("alerted", false), "being spotted by anyone else costs rapport and tips nobody off")

	# ---------------------------------------------------------------- informants
	var gi: RefCounted = DetectiveGame.new(4)
	var ki: String = String(gi._truth["killer"])
	ok(gi.street_contacts().is_empty(), "the street says nothing until you have seen the body")
	gi.examine(gi.scene_lot(), "body")
	var contacts: Array = gi.street_contacts()
	ok(contacts.size() >= 1 and contacts.size() <= 3 and not contacts.has(ki) and not contacts.has(String(gi._truth["victim"])), "the street gives you up to three contacts, never the dead (%s)" % [contacts])
	ok(gi.det.known.values().any(func(en): return (en["claims"] as Array).any(func(c): return c["predicate"] == "trades_tips")), "who trades tips is a claim in the notebook")
	var f0: int = int(gi.det.res["favours"])
	var tip: Dictionary = gi.informant_tip(String(contacts[0]))
	ok(tip["ok"] and int(gi.det.res["favours"]) == f0 - 1 and (tip["learned"] as Array).size() == 1, "a tip costs a favour and lands in the notebook")
	var tc: Dictionary = tip["learned"][0]["claims"][0]
	ok(float(tc["certainty"]) < 1.0 and tc["kind"] == "said", "and it is hearsay, with the certainty it was told with (%s)" % tc["certainty"])
	gi.det.res["favours"] = 0
	ok(not gi.informant_tip(String(contacts[0]))["ok"], "no favours, no tips")
	var n_true := 0
	var n_false := 0
	for sd in range(20, 44):
		var gt: RefCounted = DetectiveGame.new(sd)
		gt.examine(gt.scene_lot(), "body")
		var cs: Array = gt.street_contacts()
		if cs.is_empty():
			continue
		gt.det.res["favours"] = 9
		for c in cs:
			var tr: Dictionary = gt.informant_tip(String(c))
			if tr["ok"] and not (tr["learned"] as Array).is_empty():
				var tag: String = String(gt._truth["claim_tags"].get(tr["learned"][0]["claims"][0]["cid"], "true"))
				if tag == "false":
					n_false += 1
				else:
					n_true += 1
				ok(Lib.problems(String(tr["text"])).is_empty(), "tip text is clean: %s" % [Lib.problems(String(tr["text"]))])
	ok(n_true >= 5 and n_false >= 1, "tips may be false (%d honest, %d wrong over 24 cases)" % [n_true, n_false])

	# ---------------------------------------------------------------- deals
	var gd0: RefCounted = DetectiveGame.new(2)
	ok(not gd0.plea_deal(String(gd0._truth["killer"]))["ok"], "a deal needs someone in custody")
	var acc_guilty := 0
	var acc_wrong := 0
	var refused := 0
	for sd2 in [2, 3, 5, 6, 7, 8]:
		var gd: RefCounted = DetectiveGame.new(sd2)
		var kd: String = String(gd._truth["killer"])
		gd.court["custody"] = kd
		gd.court["trial_day"] = 9
		gd.court["sess"] = {"rapport": 20.0, "resistance": 60.0, "fatigue": 100.0, "sessions": 5, "pressure": 3}
		gd.det.res["favours"] = 4
		var pr: Dictionary = gd.plea_deal(kd)
		if pr["accepted"]:
			acc_guilty += 1
			var inm: Dictionary = gd.inmate(kd)
			ok(not inm.is_empty() and int(inm["sentence"]) == Informants.PLEA_SENTENCE and gd.solved() and int(gd.det.res["favours"]) == 2, "seed %d: a plea from the killer closes the case at the reduced sentence for two favours (%s)" % [sd2, inm.get("sentence", "-")])
			ok(gd.det.known.values().any(func(en): return (en["claims"] as Array).any(func(c): return c["predicate"] == "confessed" and String(c["item"]) != "")), "and the statement holds the detail only the killer knew")
		else:
			refused += 1
			ok(int(gd.det.res["favours"]) == 3 and gd.court.get("custody", "") == kd, "seed %d: a refused deal gives one favour back and leaves them in custody" % sd2)
		# an exhausted innocent, held for days
		var gx: RefCounted = DetectiveGame.new(sd2)
		var inn := ""
		for p in gx.sim.order:
			if p != "player" and p != String(gx._truth["killer"]) and p != String(gx._truth["victim"]) and gx.sim.alive(gx.sim.people[p]) and gx.sim.people[p].group == "adult":
				inn = p
				break
		gx.court["custody"] = inn
		gx.court["trial_day"] = 9
		gx.court["sess"] = {"rapport": 0.0, "resistance": 45.0, "fatigue": 100.0, "sessions": 5, "pressure": 3}
		gx.det.res["favours"] = 4
		var rep0: int = int(gx.det.reputation["town"])
		var pw: Dictionary = gx.plea_deal(inn)
		if pw["accepted"]:
			acc_wrong += 1
			ok(gx.jail.any(func(i): return i["id"] == inn) and not gx.solved() and gx._truth.get("false_conviction", "") == inn, "seed %d: an exhausted innocent signs, and is in a cell while the case is still open" % sd2)
			ok(int(gx.det.reputation["town"]) < rep0 and gx.det.cases_failed >= 1, "and the town and the Sheriff remember it")
			ok((gx.det.deals as Array).any(func(dl): return dl["target"] == inn and dl["wrongful"]), "the deal is recorded as wrongful")
	ok(acc_guilty >= 1 and acc_wrong >= 1, "a plea can close a case and can jail the wrong person (%d guilty, %d innocent, %d refused)" % [acc_guilty, acc_wrong, refused])

	print("  (resource tests took %.1fs)" % [(Time.get_ticks_msec() - t0) / 1000.0])
	print("resource_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
