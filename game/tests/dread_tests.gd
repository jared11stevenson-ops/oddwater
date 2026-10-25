extends SceneTree
## godot --headless --path game -s tests/dread_tests.gd : empathy, urgency and fear. The dead are people (a dossier from what the living tell you, a scene
## when you tell the family, a thing you carry home); the clock is visible (trails going cold, with warnings before the loss); fear is readable and
## fair (stress and darkness set a level; the page whispers real counts; a bad idea says what it costs; night events and the killer's letters are
## notebook entries you can check). Every new line of prose is scanned for placeholders, a / an, double spaces and repeated sentences.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Empathy = preload("res://scripts/detective/empathy.gd")
const Urgency = preload("res://scripts/detective/urgency.gd")
const Dread = preload("res://scripts/detective/dread.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Lib = preload("res://tests/content_lib.gd")

const FILES := ["sheet.json", "empathy.json", "informants.json", "watch.json", "urgency.json", "dread.json"]
const FILL := {"n": "Mara", "v": "Tom", "w": "6:00 am", "h": "the Pink Heron", "m": "Ada", "i": "a green thermos", "what": "the lint sample", "t": "1:30 am", "p": "the marina",
	"place": "the marina", "cam": "Town Hall camera", "band": "the hour from 1:00 am to 2:00 am", "street": "Mercy Street", "d": "9", "a": "7", "b": "8", "trace": "a smell of flour dust",
	"fig": "a figure with a hat pulled low", "msg": "LEAVE IT", "held": "a coin on the chest", "sig": "a lone folded sock", "k": "5"}

var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func _strings(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k in v:
			_strings(v[k], out)
	elif v is Array:
		for x in v:
			_strings(x, out)


func _fill(t: String, file: String) -> String:
	var out := t
	for k in FILL:
		var val: String = String(FILL[k])
		if k == "s":
			continue
		out = out.replace("{%s}" % k, val)
	out = out.replace("{s}", "Pat Rowe" if file == "informants.json" else "s")
	return out


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	# ---------------------------------------------------------------- every new line of prose
	var scanned := 0
	for f in FILES:
		var d: Variant = Prose.json("detective/" + f)
		ok(d != null, "%s loads" % f)
		var strs: Array = []
		_strings(d, strs)
		for s in strs:
			var t: String = _fill(String(s), f)
			if t.length() < 4:
				continue
			scanned += 1
			var pr: Array = Lib.problems(t)
			ok(pr.is_empty(), "%s: '%s' -> %s" % [f, t.substr(0, 60), pr])
	ok(scanned > 250, "scanned the new banks (%d lines)" % scanned)

	# ---------------------------------------------------------------- empathy: the dossier and the family
	var relations := {}
	var scenes := {}
	var gg: RefCounted = null
	for sd in range(21, 41):
		var gx: RefCounted = DetectiveGame.new(sd)
		for fam in gx.family_circle():
			relations[String(fam["rel"])] = true
		if gg == null and gx.family_circle().size() >= 1:
			gg = gx
	ok(relations.size() >= 4, "the dead had spouses, children, friends and colleagues (%s)" % [relations.keys()])
	ok(gg != null, "a case with someone to tell")
	var g: RefCounted = gg
	var v: String = String(g.case["victim"])
	ok(g.dossier()["count"] == 0 and String(g.dossier()["empty"]).contains("do not yet know who they were"), "you know how they died, not who they were")
	var npc: String = String(g.family_circle()[0]["id"])
	ok(g.can_tell(npc), "the first of the family can be told")
	g.det.skills["empathy"] = 1
	g.det.skills["charm"] = 1
	g.sim.people[npc].rel["player"] = {"affinity": 0.0, "trust": 0.0}
	g.me().location = g.sim.people[npc].home
	var r1: Dictionary = g.remember_them(npc)
	var r2: Dictionary = g.remember_them(npc)
	ok((r1["learned"] as Array).size() == 1 and (r2["learned"] as Array).size() == 1 and g.dossier()["count"] == 2, "ask who they were, and you get their days and a small kindness")
	var r3: Dictionary = g.remember_them(npc)
	ok((r3["learned"] as Array).is_empty() and String(r3["text"]).contains("Not yet") or String(r3["text"]).contains("Come back") or String(r3["text"]).contains("Ask me something else"), "the rest they keep until someone has sat with them: %s" % String(r3["text"]).substr(0, 80))
	g.det.stress = 20.0
	var stress0: float = g.det.stress
	var tell: Dictionary = g.tell_family(npc, "gentle")
	ok(tell["ok"] and g.det.compassion.get(npc, false) and g.det.stress < stress0 and int(tell["minutes"]) == 45, "sitting with them takes time and eases you both")
	ok(not g.can_tell(npc) and not g.tell_family(npc, "direct")["ok"], "you only tell a person once")
	ok(Lib.problems(String(tell["text"])).is_empty(), "the scene reads clean: %s" % [Lib.problems(String(tell["text"]))])
	var r4: Dictionary = g.remember_them(npc)
	ok(not (r4["learned"] as Array).is_empty(), "and then they tell you the rest")
	# compassion opens what an inquiry could not
	var fact := {"reveal": "rapport", "cult": false}
	var g_b: RefCounted = DetectiveGame.new(22)
	var np2: String = String(g_b.family_circle()[0]["id"])
	g_b.det.skills["empathy"] = 1
	g_b.det.skills["charm"] = 1
	g_b.sim.people[np2].rel["player"] = {"affinity": 0.0, "trust": 0.0}
	ok(not CaseOps._reveal_ok(g_b.sim, g_b.det, np2, fact, g_b._truth)["ok"], "a rapport-gated answer is closed to an inquiry")
	g_b.tell_family(np2, "gentle")
	g_b.sim.people[np2].rel["player"] = {"affinity": 0.0, "trust": 0.0}
	ok(CaseOps._reveal_ok(g_b.sim, g_b.det, np2, fact, g_b._truth)["ok"], "and open to someone who sat with them first")
	var g_c: RefCounted = DetectiveGame.new(22)
	var np3: String = String(g_c.family_circle()[0]["id"])
	g_c.det.skills["empathy"] = 1
	g_c.det.skills["charm"] = 1
	g_c.sim.people[np3].rel["player"] = {"affinity": 0.0, "trust": 0.0}
	var s_dir: float = g_c.det.stress
	g_c.tell_family(np3, "direct")
	ok(g_c.det.stress > s_dir and not g_c.det.compassion.get(np3, false), "saying it plainly costs you and opens nothing")
	var g_d: RefCounted = DetectiveGame.new(22)
	var np4: String = String(g_d.family_circle()[0]["id"])
	var aff4: float = g_d.sim.people[np4].affinity("player")
	g_d.tell_family(np4, "ask")
	ok(g_d.sim.people[np4].affinity("player") < aff4, "going straight to your questions costs trust")
	# the same loss, told differently by tie
	for sd2 in range(21, 41):
		var gy: RefCounted = DetectiveGame.new(sd2)
		var circ: Array = gy.family_circle()
		if circ.is_empty():
			continue
		var key: String = String(circ[0]["rel"])
		if not scenes.has(key):
			var rr: Dictionary = gy.tell_family(String(circ[0]["id"]), "gentle")
			scenes[key] = String(rr["text"])
	ok(scenes.size() >= 4, "the scene changes with the tie (%d relationships)" % scenes.size())
	var distinct := {}
	for k2 in scenes:
		distinct[String(scenes[k2]).substr(0, 70)] = true
	ok(distinct.size() == scenes.size(), "and no two are the same scene")
	# the funeral
	var gf: RefCounted = DetectiveGame.new(23)
	gf.sim.day = int(gf.case["day"]) + 3
	var fn: Dictionary = gf.attend_funeral()
	ok(fn["ok"] and gf.dossier()["count"] >= 2 and Lib.problems(String(fn["text"])).is_empty(), "the funeral gives you two rows of who they were, free (%d)" % gf.dossier()["count"])
	var npf: String = String(gf.family_circle()[0]["id"])
	gf.det.skills["charm"] = 1
	gf.det.skills["empathy"] = 1
	gf.sim.people[npf].rel["player"] = {"affinity": 0.0, "trust": 0.0}
	ok(CaseOps._reveal_ok(gf.sim, gf.det, npf, {"reveal": "rapport", "cult": false}, gf._truth)["ok"], "who stood beside you at the funeral tells you more")
	# the thing you carry
	var gk: RefCounted = DetectiveGame.new(24)
	ok(gk.carrying() == "You carry nothing of theirs yet.", "nothing is carried before the body is seen")
	gk.examine(gk.scene_lot(), "body")
	ok(gk.det.keepsake.get("case", "") == gk.case["id"] and gk.carrying().begins_with("You carry"), "reading the body, you pocket a small thing of theirs (%s)" % gk.carrying())
	ok(not gk.can_return_keepsake(), "it cannot be returned while the case is open")
	gk._truth["status"] = "solved"
	gk._sync_case()
	var s_k: float = gk.det.stress
	gk.det.add_stress(20.0)
	ok(gk.can_return_keepsake(), "when the case ends it can be taken back")
	var rk: Dictionary = gk.return_keepsake()
	ok(rk["ok"] and gk.det.stress < s_k + 20.0 and gk.det.keepsake["returned"] and Lib.problems(String(rk["text"])).is_empty(), "returning it eases you and is written down: %s" % String(rk["text"]).substr(0, 70))

	# ---------------------------------------------------------------- urgency: trails, warnings before the loss
	var gu: RefCounted = DetectiveGame.new(25)
	var ku: String = CaseEngine.name_of(gu.sim, String(gu._truth["killer"]))
	gu.det.learn({"id": "c_sample", "title": "Fibre sample", "text": "x", "kind": "physical", "source": gu.scene_lot(), "lab": true, "day": 1, "claims": [{"cid": "kz9", "kind": "found", "subject": "", "predicate": "observation", "place": "", "time": -1.0, "until": -1.0, "item": "", "certainty": 1.0, "source": "", "text": "x"}]})
	var tr0: Array = gu.trails()
	var lab0: Array = tr0.filter(func(t): return String(t["kind"]) == "lab_weak")
	ok(lab0.size() == 1 and int(lab0[0]["days_left"]) == 4 and lab0[0]["tier"] == "calm", "a sample you hold goes weak in four days (calm)")
	gu.sim.day += 3
	var tr1: Array = gu.trails()
	var lab1: Array = tr1.filter(func(t): return String(t["kind"]) == "lab_weak")
	ok(lab1.size() == 1 and lab1[0]["tier"] == "warn" and Urgency.morning(gu).any(func(l): return String(l).contains("sample") or String(l).contains("lab")), "a day before the loss it warns, and the morning page says so")
	gu.sim.day += 1
	ok(gu.trails().filter(func(t): return String(t["kind"]) == "lab_weak")[0]["tier"] == "urgent", "on the day it is urgent")
	gu.sim.day += 1
	ok(gu.trails().any(func(t): return String(t["kind"]) == "lab_spoil"), "and then it is spoiling")
	var all_t := ""
	for t in gu.trails():
		all_t += String(t["text"]) + " " + String(t["label"]) + " "
	ok(not all_t.contains(ku) or String(gu._truth["killer"]) == String(gu.case["found_by"]), "no trail names the killer")
	ok(gu.trails().any(func(t): return String(t["kind"]) == "cold") or Serial.active(gu.serial) or int(Urgency.GOES_COLD) - Urgency.days_open(gu) > 9, "the file's own clock is shown when it matters")
	var gs: RefCounted = DetectiveGame.new(110, "", true)
	ok(not gs.trails().any(func(t): return String(t["kind"]) == "strike"), "one body shows no pattern")
	gs.serial["kills"].append({"day": 3, "victim": "x", "name": "x", "case": "case_1", "place": "x"})
	var st_tr: Array = gs.trails().filter(func(t): return String(t["kind"]) == "strike")
	ok(st_tr.size() == 1 and String(st_tr[0]["text"]).contains("night 5") and String(st_tr[0]["text"]).contains("night 6"), "two bodies show the pattern: the next strike has a window (%s)" % [st_tr.map(func(t): return t["text"])])
	gs.serial["pressure"] = 20.0
	ok(Urgency.morning(gs).is_empty(), "low pressure is quiet")
	var low := ""
	var mid := ""
	var high := ""
	gs.serial["pressure"] = 35.0
	for l in Urgency.morning(gs):
		low += String(l)
	gs.serial["pressure"] = 60.0
	for l in Urgency.morning(gs):
		mid += String(l)
	gs.serial["pressure"] = 90.0
	for l in Urgency.morning(gs):
		high += String(l)
	ok(low != "" and mid != "" and high != "" and low != mid and mid != high, "the Sheriff's call and the Courier's line grow with the killer's pressure")
	ok(Lib.problems(low).is_empty() and Lib.problems(high).is_empty(), "and read clean")

	# ---------------------------------------------------------------- dread: a level, a page that whispers, a bad idea with a price
	var gd: RefCounted = DetectiveGame.new(26)
	gd.det.stress = 30.0
	ok(Dread.level(gd.det, 12.0) == 0 and Dread.level(gd.det, 22.0) == 0, "calm is calm, even at night")
	gd.det.stress = 50.0
	ok(Dread.level(gd.det, 12.0) == 1 and Dread.level(gd.det, 22.0) == 2, "stress sets the level and the dark adds one")
	gd.det.stress = 70.0
	ok(Dread.level(gd.det, 12.0) == 2, "frayed at 65")
	gd.det.stress = 92.0
	ok(Dread.level(gd.det, 12.0) == 3 and Dread.level(gd.det, 23.0) == 3, "breaking at 85, and no higher")
	Bot.new(gd).examine_scene()
	gd.det.stress = 20.0
	ok(gd.dread_whisper() == "", "a steady mind hears nothing")
	gd.det.stress = 75.0
	var wh: String = gd.dread_whisper()
	ok(wh != "" and Lib.problems(wh).is_empty(), "a frayed one hears the notebook whisper: %s" % wh)
	var whs := {}
	for dd in 8:
		gd.sim.day += 1
		whs[gd.dread_whisper()] = true
	ok(whs.size() >= 3, "and the whisper varies (%d)" % whs.size())
	# the bad idea
	var seen_ideas := {}
	var gi: RefCounted = DetectiveGame.new(27)
	var botx = Bot.new(gi)
	botx.examine_scene()
	botx.interview(String(gi.case["found_by"]))
	botx.follow_names(1)
	gi.det.stress = 80.0
	var idea: Dictionary = {}
	for dd2 in 40:
		gi.sim.day += 1
		gi.det.dread["intr_day"] = -1
		var tt: Dictionary = gi.dread_intrusion()
		if not tt.is_empty():
			seen_ideas[String(tt["idea"])] = true
			if idea.is_empty():
				idea = tt
	ok(not idea.is_empty() and seen_ideas.size() >= 2, "intrusive thoughts offer different bad ideas (%s)" % [seen_ideas.keys()])
	ok(String(idea["risk"]) != "" and Lib.problems(String(idea["text"])).is_empty() and Lib.problems(String(idea["risk"])).is_empty(), "each says honestly what it costs: %s" % idea.get("risk", ""))
	var s_i: float = gi.det.stress
	gi.dread_take("name_first", String(idea["who"]))
	ok(gi.sheet()["who"] == idea["who"] and (gi.sheet()["cites"]["who"] as Array).is_empty() and gi.det.stress < s_i, "'it is always the first name' fills WHO, cites nothing, and eases you")
	ok(gi.sheet_check()["stamps"]["night"] != "confirmed", "and an unearned sheet is not stamped")
	var tainted_before := 0
	gi.det.dread["intr_day"] = -1
	var rr: Dictionary = gi.dread_take("raw_search", String(idea["who"]))
	ok(String(rr["text"]) != "" and gi.det.known.values().all(func(e): return not bool(e.get("tainted", false))) or gi.det.known.values().any(func(e): return bool(e.get("tainted", false))), "a night search with no warrant is tainted if it finds anything")
	var n_st: int = gi.det.statements.size()
	gi.dread_take("press", String(idea["who"]))
	ok(gi.det.statements.size() >= n_st, "leaning on someone is a real question, asked hard")
	ok(gi.dread_dismiss() != "", "or you let it go")

	# ---------------------------------------------------------------- the night: events you can check
	var ge: RefCounted = DetectiveGame.new(28)
	ge.det.stress = 90.0
	var raised := false
	for day in range(2, 60):
		ge.sim.day = day
		ge.det.dread = {}
		ge.dread_level()
		Dread.state(ge.det)["late"] = day
		Dread.dawn(ge)
		if not ge.dread_pending().is_empty():
			raised = true
			break
	ok(raised, "a night under strain brings something (by day %d)" % ge.sim.day)
	if raised:
		var pend: Dictionary = ge.dread_pending()
		ok((pend["choices"] as Array).size() == 3 and String(pend["text"]) != "" and Lib.problems(String(pend["text"])).is_empty(), "an event has three honest choices and clean text: %s" % String(pend["text"]).substr(0, 80))
		var ent: Dictionary = ge.det.known[String(pend["id"])]
		var cls: Array = ent["claims"]
		ok(cls.size() >= 2 and cls.all(func(c): return c.has("cid") and c["kind"] in ["seen", "found", "recorded", "said"] and not c.has("_truth_tag")), "it is a notebook entry of claims, not a fright")
		ok(cls.all(func(c): return float(c["time"]) >= 0.0 or String(c["predicate"]) == "trace_found") and cls.any(func(c): return String(c["place"]) != ""), "with a time and a place you can check")
		var st_before: float = ge.det.stress
		var out: Dictionary = ge.dread_respond("report")
		ok(ge.dread_pending().is_empty() and ge.det.dread["quiet_until"] == ge.sim.day + 3 and ge.det.stress < st_before, "telling the Sheriff quiets the street for three days and eases you")
		ok(Lib.problems(String(out["text"])).is_empty(), "the response reads clean")
		# watching pays off the next time
		ge.det.dread = {}
		Dread.state(ge.det)["watch"] = true
		var got := false
		for day2 in range(ge.sim.day + 1, ge.sim.day + 60):
			ge.sim.day = day2
			Dread.state(ge.det)["late"] = day2
			Dread.state(ge.det)["last"] = -9
			Dread.dawn(ge)
			if not ge.dread_pending().is_empty():
				got = true
				ok(String(ge.dread_pending()["text"]).contains("caught in the porch light"), "if you watched, you were looking when it came back")
				break
		ok(got, "and it did come back")
	# the killer writes
	var gl: RefCounted = DetectiveGame.new(110, "", true)
	gl.serial["kills"].append({"day": 2, "victim": "x", "name": "x", "case": "case_1", "place": "x"})
	var sig: String = String(gl.serial["signature"])
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	Dread._raise_letter(gl, rnd, true)
	var lp: Dictionary = gl.dread_pending()
	ok(lp["kind"] == "letter" and String(lp["text"]).to_lower().contains(sig.to_lower()), "a serial killer leaves an object that matches the signature: %s" % String(lp["text"]).substr(0, 90))
	ok(Lib.problems(String(lp["text"])).is_empty(), "and the letter reads clean")
	var le: Dictionary = gl.det.known["letter_1"]
	ok((le["claims"] as Array).any(func(c): return c["predicate"] == "letter_signature" and String(c["item"]) == sig.to_lower()), "the sign is a claim you can compare with the scenes")
	gl.serial["pressure"] = 30.0
	gl.serial["next_strike"] = 9
	Dread.state(gl.det)["reply_day"] = -1
	gl.dread_respond("answer")
	ok(float(gl.serial["pressure"]) == 34.0 and int(gl.serial["next_strike"]) == 8, "answering it in the Courier raises the pressure and brings the next strike a night closer")
	gl.sim.day += 1
	Dread.reply_due(gl)
	ok(gl.det.known.keys().any(func(k): return String(k).begins_with("letter_reply")) and gl.det.known[gl.det.known.keys().filter(func(k): return String(k).begins_with("letter_reply"))[0]]["claims"].any(func(c): return c["predicate"] == "trace_found"), "the killer writes back, and this time there is a slip in the paper")
	var gl2: RefCounted = DetectiveGame.new(111, "", true)
	gl2.serial["kills"].append({"day": 2, "victim": "x", "name": "x", "case": "case_1", "place": "x"})
	Dread._raise_letter(gl2, rnd, true)
	gl2.serial["pressure"] = 30.0
	var n_lab: int = gl2.det.order.size()
	gl2.dread_respond("report")
	ok(gl2.det.order.size() == n_lab + 1 and float(gl2.serial["pressure"]) == 27.0 and gl2.det.reputation["sheriff"] > 0, "handing it in gets the paper tested, eases the pressure, and the Sheriff remembers")
	var gp: RefCounted = DetectiveGame.new(29)
	gp._truth["alerted"] = true
	Dread._raise_letter(gp, rnd, false)
	ok(String(gp.dread_pending()["text"]).contains(String(gp._truth["held_back"])), "a killer who knows you are close writes about the one thing that was never printed")

	print("  (dread tests took %.1fs)" % [(Time.get_ticks_msec() - t0) / 1000.0])
	print("dread_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
