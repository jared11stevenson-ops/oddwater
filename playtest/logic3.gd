extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const CE = preload("res://scripts/detective/case_engine.gd")
func p(s) -> void: print(s)
func _initialize() -> void:
	for mode in ["killer_full", "killer_weak", "innocent"]:
		var g = DG.new(21)
		var c: Dictionary = g.case
		var bot = Bot.new(g.sim, c, g.det)
		if mode == "killer_full": bot.solve()
		else: bot.examine_scene(); bot.interview(c["found_by"])
		var t: String = c["killer"] if mode != "innocent" else (c["suspects"][0] if c["suspects"][0] != c["killer"] else c["suspects"][1])
		var a = g.arrest(t)
		p("[%s] arrest -> %s | %s" % [mode, a.get("ok"), str(a.get("text")).substr(0,200)])
		g.save("user://pt3.json")
		var lg = DG.load_detective("user://pt3.json")
		p("  loaded custody=%s trial_day=%s" % [str(lg.court.get("custody")), str(lg.court.get("trial_day"))])
		for ap in ["rapport", "evidence", "pressure", "pressure", "pressure", "pressure", "pressure"]:
			var r = g.interrogate(ap)
			p("  interrogate %s -> %s learned=%d" % [ap, str(r["text"]).substr(0,140), r["learned"].size()])
		var guard := 0
		while not g.trial_ready() and guard < 10:
			g.end_day(); g.dawn(); guard += 1
		p("  trial ready after %d nights day %d; case victim same=%s custody=%s" % [guard, g.sim.day, str(g.case["victim"]==c["victim"]), g.court["custody"]])
		var res = g.run_trial()
		p("  TRIAL %s conf %s wrongful %s attacks %d" % [res["verdict"], str(res["confidence"]), str(res.get("wrongful")), res["attacks"].size()])
		for at in res["attacks"]: p("     attack: " + str(at))
		p("  jail=%s rep=%s status=%s stress=%d" % [str(g.jail.size()), str(g.det.reputation), g.case["status"], int(g.det.stress)])
		if g.jail.size() > 0:
			var id: String = g.jail[0]["id"]
			for tp in ["talk", "crime", "town", "profile"]:
				var v = g.visit(id, tp); p("   visit %s: %s" % [tp, str(v["text"]).substr(0, 160)])
			var ap = g.appeal(id); p("   appeal: " + str(ap).substr(0, 220))
			g.save("user://pt3.json")
			var lg2 = DG.load_detective("user://pt3.json")
			p("   reloaded jail=%d inmate rapport same=%s" % [lg2.jail.size(), str(lg2.jail[0]["rapport"] == g.jail[0]["rapport"])])
		# does a day pass after solved: next case
		for d in 4: g.end_day(); g.dawn()
		p("  4 nights later: case victim changed=%s, status=%s, newcomers=%d, jail=%d" % [str(g.case["victim"] != c["victim"]), g.case["status"], g.newcomers.size(), g.jail.size()])
		p("  killer (%s) alive/free? jailed=%s taken=%s" % [c["killer"], str(g.sim.people[c["killer"]].jailed), str(g.sim.people[c["killer"]].taken)])
		if mode == "innocent": p("  innocent jailed? " + str(g.sim.people[t].jailed) + " killer free; case status " + g.case["status"])
	# time limits: spend lots of time in a day
	var g = DG.new(21)
	var c: Dictionary = g.case
	var bot = Bot.new(g.sim, c, g.det)
	bot.solve()
	p("TIME: after full bot solve clock=%d hour=%.1f day=%d phase=%s minutes_pending" % [g.sim.clock, g.sim.hour_now(), g.sim.day, g.phase])
	g.flush_time()
	p("TIME: after flush clock=%d hour=%.1f day=%d phase=%s" % [g.sim.clock, g.sim.hour_now(), g.sim.day, g.phase])
	# ask the same suspect same Q repeatedly
	var s: String = c["suspects"][0]
	var r1 = g.ask(s, "alibi", ""); var r2 = g.ask(s, "alibi", ""); var r3 = g.ask(s, "victim", ""); var r4 = g.ask(s, "victim", "")
	p("REPEAT alibi: [%s] / [%s]" % [str(r1["text"]).substr(0,80), str(r2["text"]).substr(0,80)])
	p("REPEAT victim: [%s] / [%s]" % [str(r3["text"]).substr(0,80), str(r4["text"]).substr(0,80)])
	quit()
