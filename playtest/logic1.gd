extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const CE = preload("res://scripts/detective/case_engine.gd")
var issues := {}
func flag(kind: String, seed_v: int, text: String) -> void:
	var k := kind
	if not issues.has(k): issues[k] = []
	if issues[k].size() < 6: issues[k].append("seed %d: %s" % [seed_v, text.substr(0, 220)])
	else: issues[k].append("")
func scan(seed_v: int, label: String, t: String) -> void:
	if t.contains("{") or t.contains("}"): flag("placeholder", seed_v, label + ": " + t)
	if t.contains("  "): flag("double_space", seed_v, label + ": " + t)
	var re := RegEx.new()
	re.compile("\\b[Aa] [aeiouAEIOU]\\w+")
	for m in re.search_all(t):
		var wd: String = m.get_string().to_lower()
		if not (wd.contains("a u") or wd.contains("a one") or wd.contains("a eu")): flag("a_vs_an", seed_v, label + ": ..." + m.get_string() + " in " + t)
	re.compile("\\b[Aa]n [^aeiouAEIOUh]\\w+")
	for m in re.search_all(t): flag("an_vs_a", seed_v, label + ": " + m.get_string() + " in " + t)
	for bad in ["null", "<null>", "Nil", "[object", "(Object", "..", " ,", " .", "their own own", "the the ", " a a ", " to to "]:
		if t.contains(bad) and not (bad == ".." and t.contains("...")): flag("junk:" + bad, seed_v, label + ": " + t)
	if t.strip_edges() == "": flag("empty_text", seed_v, label)
func _initialize() -> void:
	var stats := []
	for s in range(1, 41):
		var serial := s % 8 == 0
		var g = DG.new(s, "", serial)
		var c: Dictionary = g.case
		var rec := {"seed": s, "serial": serial, "suspects": c["suspects"].size(), "clues": c["clues"].size(), "motive": c["motive"], "method": c["method"]}
		# lazy attempt: only the scene + accuse killer
		var g2 = DG.new(s, "", serial)
		var bot2 = Bot.new(g2.sim, g2.case, g2.det)
		bot2.examine_scene()
		var lz: Dictionary = DG.CaseOps.judge(g2.sim, g2.case, g2.det, g2.case["killer"], g2.case["motive"], g2.case["method"])
		rec["lazy_verdict"] = lz["verdict"]; rec["lazy_cats"] = lz["cats"]; rec["lazy_total"] = lz["total"]
		# scene + finder interview
		bot2.interview(g2.case["found_by"])
		lz = DG.CaseOps.judge(g2.sim, g2.case, g2.det, g2.case["killer"], g2.case["motive"], g2.case["method"])
		rec["lazy2_verdict"] = lz["verdict"]
		# full bot
		var bot = Bot.new(g.sim, g.case, g.det)
		var r: Dictionary = bot.solve()
		rec["bot_accused_right"] = r["accused"] == c["killer"]
		rec["bot_verdict"] = r["result"]["verdict"]
		rec["entries"] = g.det.order.size()
		rec["statements"] = g.det.statements.size()
		# which clues are never discovered by bot?
		var missing := []
		for id in c["clues"]:
			if not g.det.has(id): missing.append(id)
		rec["undiscovered_clues"] = missing
		# text scan
		for eid in g.det.order:
			var e: Dictionary = g.det.known[eid]
			scan(s, "entry " + str(eid), String(e.get("text", "")))
			scan(s, "title " + str(eid), String(e.get("title", "")))
		for st in g.det.statements:
			scan(s, "stmt " + String(st["npc"]) + "/" + String(st["topic"]), String(st["text"]))
		scan(s, "opening", g.opening()); scan(s, "briefing", g.briefing()); scan(s, "objective", g.objective())
		# every ask on every NPC near scene: return empty?
		var empties := 0
		var asked := 0
		for id in c["suspects"] + [c["found_by"]]:
			for t in ["victim", "suspects", "saw", "alibi", "know"]:
				var res: Dictionary = g.ask(id, t, "")
				asked += 1
				var txt := String(res.get("text", ""))
				scan(s, "ask %s/%s" % [id, t], txt)
				if txt == "": empties += 1; flag("empty_answer", s, "%s %s -> %s" % [id, t, str(res).substr(0, 100)])
		rec["empty_answers"] = empties
		# accuse right + full cycle
		var res2: Dictionary = g.accuse(c["killer"], c["motive"], c["method"])
		scan(s, "accuse_text", String(res2["text"]))
		scan(s, "episode", String(res2.get("episode", {}).get("text", str(res2.get("episode", "")))))
		# nights
		var txts := []
		for d in 6:
			g.end_day(); var dn := g.dawn()
			for t in g.today: scan(s, "today", String(t))
			if g.case["victim"] != c["victim"] and not rec.has("next_case_day"): rec["next_case_day"] = g.sim.day
		rec["newcomers"] = g.newcomers.size()
		rec["pressure"] = g.pressure()
		rec["rep"] = str(g.det.reputation)
		rec["day"] = g.sim.day
		# save/load roundtrip
		g.save("user://pt_save.json")
		var lg = DG.load_detective("user://pt_save.json")
		if lg == null: flag("load_failed", s, "")
		else:
			var a := JSON.stringify(g.to_dict()); var b := JSON.stringify(lg.to_dict())
			if a != b: flag("save_roundtrip_diff", s, "len %d vs %d" % [a.length(), b.length()])
			if lg.sim.day != g.sim.day or lg.case.get("killer") != g.case.get("killer"): flag("save_state_mismatch", s, "")
		stats.append(rec)
	for r in stats: print("REC ", JSON.stringify(r))
	for k in issues: print("ISSUE ", k, " n=", issues[k].size(), " ", issues[k].filter(func(x): return x != ""))
	quit()
