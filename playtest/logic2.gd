extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const CE = preload("res://scripts/detective/case_engine.gd")
const Serial = preload("res://scripts/detective/serial.gd")
func p(s: String) -> void: print(s)
func tod_lines(g, c) -> void:
	var vname: String = CE.name_of(g.sim, c["victim"])
	var bad := 0
	for eid in g.det.order:
		var e: Dictionary = g.det.known[eid]
		if not String(eid).begins_with("cctv"): continue
		for line in String(e.get("text", "")).split("\n"):
			if line.contains(vname) or line.contains("Someone you can place as " + vname):
				# parse time
				var parts := line.split(" ")
				var t := parts[0].split(":")
				if t.size() == 2:
					var h: float = fmod(float(t[0]), 12.0) + (12.0 if parts[1].begins_with("p") else 0.0) + float(t[1]) / 60.0
					if h < 12.0: h += 24.0
					if h > float(c["hour"]) + 0.01: bad += 1; p("  VICTIM-AFTER-DEATH %s tod=%.2f line=%s" % [c["victim"], c["hour"], line])
func _initialize() -> void:
	# chain: 8 cases per seed, mixed behaviours
	for s in [3, 14, 27, 41, 58]:
		var g = DG.new(s)
		p("=== chain seed %d, residents %d" % [s, g.sim.order.size()])
		for n in 6:
			var c: Dictionary = g.case
			var bot = Bot.new(g.sim, c, g.det)
			if n % 3 == 1:
				# wrong accusation
				bot.examine_scene()
				var wrong: String = c["suspects"][0] if c["suspects"][0] != c["killer"] else c["suspects"][1]
				var r: Dictionary = g.accuse(wrong, "money", "knife")
				p("  case %d WRONG -> %s | %s | rep %s stress %d" % [n, r["verdict"], r["text"], str(g.det.reputation), int(g.det.stress)])
			elif n % 3 == 2:
				var r: Dictionary = bot.lazy()
				p("  case %d lazy-killer -> %s cats %d total %d" % [n, r["result"]["verdict"], r["result"]["cats"], r["result"]["total"]])
				var r2 = g.accuse(c["killer"], c["motive"], c["method"])
				p("    via game.accuse -> %s status=%s" % [r2["verdict"], g.case["status"]])
			else:
				var r: Dictionary = bot.solve()
				tod_lines(g, c)
				var r2 = g.accuse(c["killer"], c["motive"], c["method"])
				p("  case %d full -> %s" % [n, r2["verdict"]])
			var days := 0
			while g.case["victim"] == c["victim"] and days < 12:
				g.end_day(); g.dawn(); days += 1
			p("   -> next victim after %d nights; day %d; status %s; serial=%s; newcomers=%d; residents=%d; stress=%d; custody=%s jail=%d" % [days, g.sim.day, g.case["status"], str(Serial.active(g.serial)), g.newcomers.size(), g.sim.order.size(), int(g.det.stress), str(g.court["custody"]), g.jail.size()])
			p("   today: " + str(g.today).substr(0, 300))
		p("  chronicle: " + str(g.chronicle).substr(0, 600))
	# unsolved: just wait 20 days (non-serial): what happens?
	var g = DG.new(9)
	for d in 20:
		g.end_day(); g.dawn()
	p("UNSOLVED 20 days: day %d status %s victim %s deaths? alive=%d objective=%s" % [g.sim.day, g.case["status"], g.case["victim"], g.sim.order.filter(func(i): return g.sim.alive(g.sim.people[i])).size(), g.objective()])
	# serial: ignore until failure
	g = DG.new(8, "", true)
	for d in 20:
		g.end_day(); g.dawn()
		if d % 3 == 0: p("SERIAL d%d day=%d kills=%d pressure=%d status=%s obj=%s" % [d, g.sim.day, g.serial["kills"].size(), int(g.pressure()), g.serial["status"], g.objective()])
	p("SERIAL final: " + str(g.serial["status"]) + " news=" + str(g.news().size()))
	p("today: " + str(g.today).substr(0,400))
	var alive: int = g.sim.order.filter(func(i): return g.sim.alive(g.sim.people[i])).size()
	p("alive %d of %d" % [alive, g.sim.order.size()])
	quit()
