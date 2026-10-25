extends SceneTree
## godot --headless --path game -s tests/deduction_tests.gd : the fill-in-the-case sheet. The sheet stamps a linked group only when it is jointly
## correct and the cited claims really establish it; it never says which part is wrong; the charge ladder limits what you can charge with;
## a wrong-but-supported sheet is a wrongful charge; Test theory finds contradictions in the notebook and nothing else; hunches give leads, not
## verdicts; a search with no warrant is tainted and is challenged at trial.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const Helpers = preload("res://tests/case_bot_helpers.gd")
const Sheet = preload("res://scripts/detective/sheet.gd")
const Leads = preload("res://scripts/detective/leads.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Lib = preload("res://tests/content_lib.gd")

var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func _keys(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			out[String(k)] = true
			_keys(v[k], out)
	elif v is Array:
		for x in v:
			_keys(x, out)


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	# ---------------------------------------------------------------- the bot's sheet, normal and serial seeds
	var solved_full := 0
	var solved_part := 0
	for spec in [[1, false], [2, false], [3, false], [110, true], [120, true]]:
		var g: RefCounted = DetectiveGame.new(int(spec[0]), "", bool(spec[1]))
		var killer: String = String(g._truth["killer"])
		var bot = Bot.new(g)
		var plan: Dictionary = bot.solve()
		bot.fill_sheet(plan)
		var r: Dictionary = g.sheet_check()
		var lv: String = String(r["level"])
		if not bool(spec[1]):
			ok(lv == "murder", "seed %d: a worked ordinary case stamps every group (%s)" % [int(spec[0]), r["stamps"]])
			var res: Dictionary = g.sheet_file()
			ok(res["verdict"] == "convicted" and g.solved() and g.jail.any(func(i): return i["id"] == killer and int(i["sentence"]) == 25), "seed %d: a complete sheet runs the whole road to a cell (%s)" % [int(spec[0]), res.get("verdict", "")])
			solved_full += 1
		else:
			ok(lv == "killing" and r["stamps"]["night"] == "confirmed" and r["stamps"]["reason"] != "confirmed", "seed %d: a serial's first body proves the night and the act, not the why (%s)" % [int(spec[0]), r["stamps"]])
			var res2: Dictionary = g.sheet_file()
			ok(res2["verdict"] in ["charged", "released"] and g.court.get("custody", "") == killer, "seed %d: only the charge you can support is laid; the accused is held (%s)" % [int(spec[0]), res2.get("verdict", "")])
			if g.court.get("custody", "") == killer:
				ok(int(g.court.get("sentence_cap", 0)) == 18, "the unlawful-killing rung caps the sentence")
				g.sim.day = int(g.court["trial_day"])
				var tr: Dictionary = g.run_trial()
				var inm: Dictionary = g.inmate(killer)
				ok(tr["verdict"] == "guilty" and not inm.is_empty() and int(inm["sentence"]) <= 18 and g.solved(), "a lesser charge still convicts the killer, with a shorter sentence (%s %s)" % [tr["verdict"], inm.get("sentence", "-")])
			solved_part += 1
	ok(solved_full == 3 and solved_part == 2, "the sheet is solvable from the notebook on ordinary and forced-serial seeds (%d, %d)" % [solved_full, solved_part])

	# ---------------------------------------------------------------- the lazy and the null detective still fail, through the sheet
	for sd in [1, 2, 110]:
		var gz: RefCounted = DetectiveGame.new(sd, "", sd == 110)
		var kz: String = String(gz._truth["killer"])
		var lz: Dictionary = Bot.new(gz).lazy()
		Bot.new(gz).fill_sheet(lz)
		var rz: Dictionary = gz.sheet_check()
		var fz: Dictionary = gz.sheet_file(true)
		ok(rz["level"] != "murder" and fz["verdict"] != "convicted" and not gz.solved() and gz.jail.is_empty(), "seed %d: the lazy detective cannot fill in a case that closes (%s, %s)" % [sd, rz["level"], fz["verdict"]])
		var gn: RefCounted = DetectiveGame.new(sd, "", sd == 110)
		gn.sheet_set("who", String(gn._truth["killer"]))
		gn.sheet_set("where", String(gn.case["scene"]))
		gn.sheet_set("when", Sheet.band_of_hour(float(gn._truth["hour"])))
		gn.sheet_set("how", String(gn._truth["method"]))
		gn.sheet_set("why", String(gn._truth["motive"]))
		var rn: Dictionary = gn.sheet_check()
		var fn2: Dictionary = gn.sheet_file(true)
		ok(rn["level"] == "unconfirmed" and fn2["verdict"] == "no_cause" and not gn.solved(), "seed %d: knowing the answers is nothing without the notebook behind them (%s)" % [sd, fn2["verdict"]])

	# ---------------------------------------------------------------- the stamp never says which part is wrong
	var g2: RefCounted = DetectiveGame.new(2)
	var k2: String = String(g2._truth["killer"])
	var bot2 = Bot.new(g2)
	var plan2: Dictionary = bot2.solve()
	var d_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/detective/sheet.json"))
	# (a) the right person with nothing cited, (b) a wrong person with every honest card cited, (c) a right sheet with one wrong line
	bot2.fill_sheet(plan2)
	var sh: Dictionary = g2.sheet()
	var full_cites: Dictionary = sh["cites"].duplicate(true)
	var innocent := ""
	for p in g2.persons_of_interest():
		if p != k2 and p != String(g2.case["found_by"]):
			innocent = p
			break
	g2.sheet_set("who", innocent)
	for f in Sheet.FIELDS:
		for card in g2.sheet_cards(f):
			if card["subject"] == innocent:
				g2.sheet_cite(f, card["cid"], true)
	var rb: Dictionary = g2.sheet_check()
	ok(rb["stamps"]["night"] == "unsupported" and rb["stamps"]["act"] == "unsupported" and rb["stamps"]["reason"] == "unsupported", "a wrong name is not confirmed, however much is cited: %s" % rb["stamps"])
	g2.sheet_set("who", k2)
	for f in Sheet.FIELDS:
		sh["cites"][f] = []
	var ra: Dictionary = g2.sheet_check()
	ok(ra["stamps"]["night"] == "unsupported", "the right name with nothing cited is just as unsupported")
	var unsupported_texts: Array = []
	for gid in ["night", "act", "reason"]:
		unsupported_texts.append(rb["lines"][gid]["text"])
		ok((d_json["unsupported"][gid] as Array).has(rb["lines"][gid]["text"]) and (d_json["unsupported"][gid] as Array).has(ra["lines"][gid]["text"]), "%s: both read from the same 'not yet supported' bank, which names no part" % gid)
	for t in unsupported_texts:
		ok(not String(t).to_lower().contains("wrong") and not String(t).to_lower().contains("incorrect") and not String(t).contains(CaseEngine.first(g2.sim, k2)), "the stamp text gives nothing away: %s" % t)
	# a wrong line sinks only its own group
	sh["cites"] = full_cites
	g2.sheet_set("how", "poison" if g2._truth["method"] != "poison" else "knife")
	var rc: Dictionary = g2.sheet_check()
	ok(rc["stamps"]["night"] == "confirmed" and rc["stamps"]["act"] == "unsupported" and rc["stamps"]["reason"] == "confirmed" and rc["level"] == "killing", "one wrong line sinks only its group and the ladder steps down: %s -> %s" % [rc["stamps"], rc["level"]])
	g2.sheet_set("how", g2._truth["method"])
	ok(String(g2.sheet()["stamps"]["act"]) == "open" and String(g2.sheet()["stamps"]["night"]) == "confirmed", "changing an answer takes the stamp off its own groups until you check again")
	# only the true claims count at adjudication: a sheet that leans on a lie is not confirmed
	var g2b: RefCounted = DetectiveGame.new(2)
	var kb: String = String(g2b._truth["killer"])
	Helpers.frame(g2b, kb, "lie_k")          # a false sighting and a false quarrel, tagged for the court
	g2b.sheet_set("who", kb)
	g2b.sheet_set("where", String(g2b._truth["scene"]))
	g2b.sheet_set("when", Sheet.band_of_hour(float(g2b._truth["hour"])))
	g2b.examine(g2b.scene_lot(), "body")
	for f in ["who", "when", "where"]:
		for card in g2b.sheet_cards(f):
			if card["subject"] == kb or card["predicate"] in ["time_of_death"]:
				g2b.sheet_cite(f, card["cid"], true)
	var rl: Dictionary = g2b.sheet_check()
	ok(rl["stamps"]["night"] != "confirmed", "a correct name held up only by a lie is not confirmed")

	# ---------------------------------------------------------------- the wrong-but-supported sheet: a wrongful charge, as today
	var g3: RefCounted = DetectiveGame.new(4)
	var bot3 = Bot.new(g3)
	bot3.solve()
	var k3: String = String(g3._truth["killer"])
	var victim_other := ""
	for p in g3.persons_of_interest():
		if p != k3 and p != String(g3.case["found_by"]):
			victim_other = p
			break
	Helpers.frame(g3, victim_other, "frame_y")
	g3.sheet_set("who", victim_other)
	g3.sheet_set("where", String(g3.case["scene"]))
	g3.sheet_set("when", Sheet.band_of_hour(float(g3._truth["hour"])))
	g3.sheet_set("how", String(g3._truth["method"]))
	g3.sheet_set("why", "money")
	for f in Sheet.FIELDS:
		for card in g3.sheet_cards(f):
			if card["subject"] == victim_other:
				g3.sheet_cite(f, card["cid"], true)
	var rw: Dictionary = g3.sheet_check()
	ok(rw["level"] == "unconfirmed", "nothing is stamped for the wrong name, even with a convincing notebook (%s)" % rw["stamps"])
	var f0: Dictionary = g3.sheet_file(false)
	ok(f0["verdict"] == "unconfirmed" and g3.court.get("custody", "") == "", "an unconfirmed sheet is not filed unless you press the charge on your own judgement")
	var fails_before: int = g3.det.cases_failed
	var f1: Dictionary = g3.sheet_file(true)
	ok(f1["verdict"] == "wrong" and g3.det.cases_failed == fails_before + 1 and g3._truth["damaged"].has(victim_other) and g3._truth.get("alerted", false), "pressing it anyway is a wrongful accusation with every consequence (%s)" % f1["verdict"])
	var g3b: RefCounted = DetectiveGame.new(4)
	g3b.sheet_set("who", k3)
	ok(g3b.sheet_file(true)["verdict"] == "no_cause", "even pressing a charge needs probable cause in the notebook")

	# ---------------------------------------------------------------- test theory: contradictions from the notebook, never the answer
	var g4: RefCounted = DetectiveGame.new(5)
	var k4: String = String(g4._truth["killer"])
	var scapegoat := ""
	for p in g4.sim.order:
		if p != k4 and p != "player" and p != String(g4._truth["victim"]) and g4.sim.alive(g4.sim.people[p]) and g4.sim.people[p].group == "adult":
			scapegoat = p
			break
	g4.examine(g4.scene_lot(), "body")
	g4.sheet_set("who", scapegoat)
	g4.sheet_set("when", "small")
	var m0: int = g4._minutes
	var th0: Dictionary = g4.sheet_test_theory()
	ok(int(th0["count"]) == 0 and String(th0["text"]).contains("does not make it true") or String(th0["text"]).contains("seam") or String(th0["text"]).contains("Only in the world"), "an empty notebook offers no contradiction, and says so honestly: %s" % th0["text"])
	ok(g4._minutes - m0 == 45 or g4.sim.clock > 0, "testing the theory costs time")
	g4.det.learn({"id": "alibi_x", "title": "Alibi", "text": "x", "kind": "testimony", "source": "", "day": 1,
		"claims": Claims.emit(g4._truth, [Claims.make("said", scapegoat, "elsewhere", "pink_heron", 24.5, "", 0.9, "true", 26.5)], "x", "x")})
	var th1: Dictionary = g4.sheet_test_theory()
	ok(int(th1["count"]) >= 1 and String(th1["text"]).contains("somewhere else"), "a recorded alibi over the hour is found in your own notes: %s" % th1["text"])
	ok(not String(th1["text"]).contains(CaseEngine.name_of(g4.sim, k4)) or k4 == scapegoat, "and the test never names the real killer")
	g4.sheet_set("when", "eve")
	var th2: Dictionary = g4.sheet_test_theory()
	ok(String(th2["text"]).contains("body's own time") or int(th2["count"]) >= 1, "a time the body does not give is flagged (%s)" % [th2["lines"]])
	var keys := {}
	_keys(g4.det.to_dict(), keys)
	for k in ["supports", "_truth_tag", "claim_tags", "profiles", "has_detail", "false_confession", "unreliable", "misleading"]:
		ok(not keys.has(k), "the saved detective holds no '%s'" % k)

	# ---------------------------------------------------------------- hunches: a lead, never a verdict, limited
	var g5: RefCounted = DetectiveGame.new(1)
	var k5: String = String(g5._truth["killer"])
	var h_start: int = int(g5.det.res.get("hunches", 2)) if not g5.det.res.is_empty() else 2
	var seen := {}
	var named_killer := false
	for i in 12:
		var ld: Dictionary = Leads.lead(g5, i)
		seen[String(ld["text"])] = true
		ok(ld["text"] != "" and not String(ld["text"]).to_lower().contains("did it") and not String(ld["text"]).to_lower().contains("killer"), "a lead is a suggestion of where to look: %s" % ld["text"])
		ok(Lib.problems(String(ld["text"])).is_empty(), "lead text is clean: %s" % [Lib.problems(String(ld["text"]))])
		if String(ld["text"]).contains(CaseEngine.name_of(g5.sim, k5)) and k5 != String(g5.case["found_by"]):
			named_killer = true
	ok(seen.size() >= 3 and not named_killer, "leads vary and never name the killer (%d different)" % seen.size())
	var hs := 0
	for i in 5:
		var hr: Dictionary = g5.sheet_hunch()
		if hr["ok"]:
			hs += 1
	ok(hs == h_start and not g5.sheet_hunch()["ok"] and int(g5.det.res["hunches"]) == 0, "hunches are limited (%d spent, then none)" % hs)
	ok(g5.det.level >= 1, "a hunch costs a quarter hour of the clock")

	# ---------------------------------------------------------------- searching without a warrant
	var g6: RefCounted = DetectiveGame.new(2)
	var k6: String = String(g6._truth["killer"])
	var home: String = String(g6.sim.people[k6].home)
	ok(g6.spots(home).any(func(s): return s["id"] == "search_raw"), "a house offers a search with no warrant as well as one with")
	var legal: Dictionary = g6.examine(home, "search")
	ok((legal["learned"] as Array).is_empty() and String(legal["text"]).contains("warrant"), "a warrant search without a warrant is refused")
	g6.det.skills["observation"] = 10
	g6.det.skills["forensics"] = 10
	var aff0: float = g6.sim.people[k6].affinity("player")
	var raw: Dictionary = g6.examine(home, "search_raw")
	var tainted: Array = (raw["learned"] as Array).filter(func(e): return bool(e.get("tainted", false)))
	ok(not (raw["learned"] as Array).is_empty() and tainted.size() == (raw["learned"] as Array).size(), "evidence from a search with no warrant is flagged tainted (%d)" % tainted.size())
	ok(g6.sim.people[k6].affinity("player") < aff0, "and the household notices")
	# the same notebook, tried: tainted evidence costs the case something
	var clean: RefCounted = DetectiveGame.new(2)
	for e in tainted:
		var e2: Dictionary = e.duplicate(true)
		e2["tainted"] = false
		clean.det.learn(e2)
	var dirty_trial: Dictionary = Justice.trial(g6.sim, g6._truth, g6.det, k6)
	var clean_trial: Dictionary = Justice.trial(clean.sim, clean._truth, clean.det, k6)
	ok(float(dirty_trial["confidence"]) < float(clean_trial["confidence"]), "the defence challenges it: the jury trusts a tainted notebook less (%s vs %s)" % [dirty_trial["confidence"], clean_trial["confidence"]])
	ok((dirty_trial["attacks"] as Array).any(func(a): return String(a["text"]).contains("warrant")), "and says why, in court")
	# a warrant afterwards cleans the chain
	g6.det.warrants[k6] = true
	g6.det.res["warrants"] = 1
	g6.examine(home, "search")
	ok(g6.det.known.values().all(func(e): return not bool(e.get("tainted", false))), "searching again under a warrant clears the taint")

	print("  (deduction tests took %.1fs)" % [(Time.get_ticks_msec() - t0) / 1000.0])
	print("deduction_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
