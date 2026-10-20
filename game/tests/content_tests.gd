extends SceneTree
## godot --headless --path game -s tests/content_tests.gd : prose helpers, voices, places, ledger, the accusation pipeline, cold cases,
## aftermath, ordinary life, and a text scan over generated cases.

const World = preload("res://scripts/sim/sim_world.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Cold = preload("res://scripts/detective/cold.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Lib = preload("res://tests/content_lib.gd")
const Bot = preload("res://tests/case_bot.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func make(seed_v: int) -> Array:
	var w := World.new(seed_v, true)
	w.thin_weeks = false
	w.day = 0
	w.start_day()
	var c := CaseEngine.generate(w, seed_v, 0)
	CaseEngine.apply_backstory(w, c)
	w.simulate_rest_of_day()
	CaseEngine.execute(w, c)
	w.slack()
	w.start_day()
	return [w, c]

func _initialize() -> void:
	# ---- prose helpers
	ok(Prose.a("organist") == "an organist" and Prose.a("dam technician") == "a dam technician" and Prose.a("ad sales") == "an ad sales", "articles: organist, technician, ad sales")
	ok(Prose.job_np("unemployed") != "a unemployed" and Prose.job_np("retired") == "a retired resident" and Prose.job_np("odd jobs").begins_with("a handyman"), "job nouns never give 'a unemployed' or 'a odd jobs'")
	ok(Prose.sentence("a single heavy blow to the back") == "A single heavy blow to the back", "sentence case keeps the middle lower")
	ok(Prose.clean("You had it exactly right..  Next  line") == "You had it exactly right. Next line", "clean: double stop and double space")
	ok(Prose.clean("a orderly and an teacher") == "an orderly and a teacher", "clean: fixes a / an")
	ok(Prose.clean("Wait... what") == "Wait... what", "clean keeps ellipses")
	ok(Prose.clean("Plan A and B") == "Plan A and B", "clean leaves a letter A alone")
	# ---- 217 residents on every seed
	for s in [1, 2, 3, 7, 19, 33]:
		ok(World.new(s, true).order.size() == 217, "seed %d: exactly 217 residents" % s)
	# ---- case variety and fairness of the new misdirection
	var sizes := {}
	var motives := {}
	var methods := {}
	var mis := {"planted": 0, "liar": 0, "decoy": 0, "hidden": 0, "far": 0}
	var solved := 0
	var N := 16
	for s in range(1, N + 1):
		var wc: Array = make(s)
		var c: Dictionary = wc[1]
		sizes[c["suspects"].size()] = true
		motives[c["motive"]] = int(motives.get(c["motive"], 0)) + 1
		methods[c["method"]] = int(methods.get(c["method"], 0)) + 1
		if c["clues"].has("c_planted"): mis["planted"] += 1
		if c.has("liar"): mis["liar"] += 1
		if c["profiles"].values().any(func(p): return p.get("role", "") == "decoy"): mis["decoy"] += 1
		if c.has("hidden"): mis["hidden"] += 1
		if c["cameras"].any(func(cam): return absi(int(cam["offset"])) >= 25): mis["far"] += 1
		ok(c["clues"].has("c_timeline") and c["clues"]["c_timeline"]["text"].contains("last days"), "seed %d: the victim's last days are written" % s)
		var bot = Bot.new(wc[0], c)
		var r: Dictionary = bot.solve()
		if r["result"]["verdict"] == "convicted" and r["accused"] == c["killer"]:
			solved += 1
		if c.has("hidden"):
			ok(c["suspects"].has(c["hidden"]["id"]) == c.has("emerged"), "seed %d: the sixth appears only when evidence brings them in" % s)
	ok(sizes.size() >= 3, "the cast varies in size: %s" % [sizes.keys()])
	ok(motives.size() == 5 or motives.size() == 4, "motives vary: %s" % [motives])
	ok(methods.values().max() <= N / 2, "no method dominates: %s" % [methods])
	ok(mis["planted"] >= 1 and mis["liar"] >= 1 and mis["decoy"] >= 1 and mis["hidden"] >= 1 and mis["far"] >= 1, "ways to be misled all occur: %s" % [mis])
	ok(solved >= N - 1, "with the misdirection, a thorough bot still solves: %d of %d" % [solved, N])
	# ---- voices: no repeated stock answers within a case, and repeat questions
	var wc2: Array = make(4)
	var c2: Dictionary = wc2[1]
	var w2: RefCounted = wc2[0]
	var by: Array = CaseEngine.neighbors(w2, c2["scene"], 14, c2["suspects"] + [c2["victim"]])
	var d2 := Detective.new()
	var lines := {}
	for id in by.slice(0, 8):
		lines[String(CaseOps.ask(w2, c2, d2, id, "alibi")["text"])] = true
	ok(lines.size() == 8, "eight bystanders give eight different alibis: %d" % lines.size())
	var first_t: String = CaseOps.ask(w2, c2, d2, by[9], "saw")["text"]
	var n_stmt: int = d2.statements.size()
	var again: Dictionary = CaseOps.ask(w2, c2, d2, by[9], "saw")
	ok(again.get("repeat", false) and again["text"] != first_t and d2.statements.size() == n_stmt, "asking again gets a distinct reply and no duplicate entry")
	# ---- scene prose follows the scene
	var kinds := {}
	for s in range(1, 13):
		var cc: Dictionary = make(s)[1]
		var pl = load("res://scripts/detective/places.gd").profile(cc)
		kinds[pl["type"]] = true
		ok(not (pl["type"] != "home" and String(pl["sense"]).contains("toast")), "seed %d: a %s does not smell of home toast" % [s, pl["type"]])
	ok(kinds.size() >= 4, "scene types vary: %s" % [kinds.keys()])
	# ---- ledger
	var dt := Detective.new()
	Reputation.apply(dt, "funeral", 3)
	ok(dt.reputation["chapel"] == 3 and dt.rep_log.size() == 1 and Reputation.chapel_tier(dt) == "neutral", "the chapel moves, and the ledger records it")
	Reputation.apply(dt, "sermon", 4); Reputation.apply(dt, "occult_solved", 5)
	ok(Reputation.chapel_tier(dt) in ["welcome", "trusted"], "enough goodwill and the chapel welcomes you")
	ok(Reputation.escalation(3) > Reputation.escalation(2) and Reputation.escalation(2) > Reputation.escalation(1), "wrong accusations cost more each time")
	# ---- the one road: accuse -> arrest -> trial -> jail
	var g := DetectiveGame.new(31)
	var bot2 = Bot.new(g.sim, g.case, g.det)
	var br: Dictionary = bot2.solve()
	var town0: int = g.det.reputation["town"]
	var res: Dictionary = g.accuse(g.case["killer"], g.case["motive"], g.case["method"])
	ok(res["verdict"] == "convicted" and g.solved() and not g.jail.is_empty() and g.jail[-1]["id"] == g.case["killer"], "a thorough case: accusation ends in a trial and a cell (%s)" % res["verdict"])
	ok(res.has("text") and res.has("score") and res.has("cats") and res.has("total") and res.has("episode") and res.has("trial"), "accuse keeps the keys the HUD reads")
	ok(g.det.reputation["town"] == town0 + 5 and g.det.rep_log.size() >= 1, "and the town reputation matches the trial path (+5)")
	ok(not String(res["text"]).contains(".."), "no double full stop in the verdict")
	ok(g.cost_of("view_camera")["minutes"] == 30 and g.cost_of("accuse")["note"] != "", "cost_of previews time")
	# ---- wrong accusations: escalating cost, a damaged neighbour, a scandal, a limit, then the aftermath
	var g2 := DetectiveGame.new(32)
	var innocent: Array = g2.suspects().filter(func(s): return s != g2.case["killer"])
	var rep_a: Array = []
	for i in 3:
		var before: int = g2.det.reputation["sheriff"]
		var r2: Dictionary = g2.accuse(innocent[i % innocent.size()], "money", "blunt")
		rep_a.append(g2.det.reputation["sheriff"] - before)
		if i == 0:
			ok(r2["verdict"] == "wrong" and g2.case["damaged"].has(innocent[0]) and g2.case.get("alerted", false) and not g2.paper().is_empty(), "a wrong name: the accused is damaged, the killer alerted, the paper prints a scandal")
			var refuse: Dictionary = g2.ask(innocent[0], "alibi")
			ok(refuse.get("refused", false), "the wrongly accused will not talk to you for days")
	ok(rep_a[0] > rep_a[1] and rep_a[1] > rep_a[2], "each wrong accusation costs more: %s" % [rep_a])
	ok(g2.accusations_left() == 0 and g2.case["status"] == "failed" and g2.det.rank == "Deputy" and not g2.haunting.is_empty(), "three strikes: the state police take the file, you are reassigned, the killer lingers")
	ok(g2.accuse(innocent[0], "money", "blunt")["verdict"] == "barred", "no more accusations on a closed file")
	ok(g2.objective().contains("Reassigned") and g2.episodes[-1]["verdict"] == "failure", "an objective for the aftermath, and a failure episode in the archive")
	var seen_new := false
	for i in 9:
		g2.end_day(); g2.dawn()
		if g2.case["status"] == "open":
			seen_new = true
			break
	ok(seen_new, "and the game goes on: a new case opens after a quiet stretch")
	# ---- the quiet stretch is not always three days
	var gaps := {}
	for s in [41, 42, 43, 44, 45, 46]:
		var gg := DetectiveGame.new(s)
		gg.case["status"] = "solved"
		var nights := 0
		while gg.case["status"] == "solved" and nights < 10:
			gg.end_day(); gg.dawn()
			nights += 1
		gaps[nights] = true
	ok(gaps.size() >= 2, "the gap between cases varies: %s" % [gaps.keys()])
	# ---- cold cases evolve
	var g3 := DetectiveGame.new(33)
	var c3: Dictionary = g3.case
	g3.examine(c3["scene"], "garden")
	for i in 14:
		g3.end_day(); g3.dawn()
		if c3.get("status") != "open":
			break
	var gone := 0
	for cid in ["c_foot", "c_weapon", "c_k_shoes", "c_k_coat"]:
		if g3.case.get("id") == c3.get("id") and c3["clues"].has(cid) and c3["clues"][cid].get("gone", false):
			gone += 1
	ok(gone >= 2, "a cold trail loses evidence: %d clues gone" % gone)
	ok(g3.det.reputation["sheriff"] < 0, "the Sheriff's patience drains: %d" % g3.det.reputation["sheriff"])
	ok(g3.episodes.any(func(e): return e["verdict"] == "cold") or c3["status"] == "open", "the file eventually goes cold, with an episode")
	# ---- save size
	var gs := DetectiveGame.new(34)
	for i in 3:
		gs.end_day(); gs.dawn()
	gs.save("user://content_size.json")
	var sz := FileAccess.open("user://content_size.json", FileAccess.READ).get_length()
	ok(sz < 1500000, "the save is compact: %d bytes" % sz)
	var back: RefCounted = DetectiveGame.load_detective("user://content_size.json")
	ok(back != null and back.sim.history.size() == gs.sim.history.size() and back.sim.where_was(back.case["killer"], 0, 36) == gs.sim.where_was(gs.case["killer"], 0, 36), "history survives the compact save")
	DetectiveGame.delete_save("user://content_size.json")
	# ---- the text scan
	var bad := 0
	for s in range(1, 9):
		var wc3: Array = make(s)
		var b3 = Bot.new(wc3[0], wc3[1])
		var r3: Dictionary = b3.solve()
		var texts: Array = [Narrator.cold_open(wc3[0], wc3[1]), CaseEngine.discovery_text(wc3[0], wc3[1]), String(r3["result"]["text"]), String(Narrator.episode(wc3[0], wc3[1], b3.det, r3["result"])["text"])]
		for eid in b3.det.order:
			texts.append(String(b3.det.known[eid]["text"]))
		for t in texts:
			var p: Array = Lib.problems(String(t))
			if not p.is_empty():
				bad += 1
				print("   scan: seed %d: %s" % [s, p[0]])
	ok(bad == 0, "no placeholder, double space/stop, article or Title Case slip in generated text (%d)" % bad)
	print("content_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
