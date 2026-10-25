extends SceneTree
## godot --headless --path game -s tests/content_scan.gd [seeds=60] : generate cases, work them, and scan every line of produced text.
## Prints the problems found and a variety report. Exit code 0 always (it is a tool); content_tests.gd asserts.

const World = preload("res://scripts/sim/sim_world.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Lib = preload("res://tests/content_lib.gd")
const Bot = preload("res://tests/case_bot.gd")
const Helpers = preload("res://tests/case_bot_helpers.gd")
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")


func make(seed_v: int) -> Array:
	var g: RefCounted = DetectiveGame.new(seed_v)
	return [g.sim, g._truth, g]


func _initialize() -> void:
	var n := 60
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var bad: Dictionary = {}
	var total_texts := 0
	var variety := {"motive": {}, "method": {}, "suspects": {}, "scene_type": {}, "open_line": {}, "alibi_default": {}, "saw_none": {}, "unease": {}, "diary": {}, "repeat": {}, "claim_killer": {}, "dropped": {}, "weather": {}}
	var counts := {"hidden": 0, "planted": 0, "liar": 0, "decoy": 0, "far_clock": 0}
	for s in range(1, n + 1):
		var wc: Array = make(s)
		var w: RefCounted = wc[0]
		var c: Dictionary = wc[1]
		var texts: Array = []
		texts.append(Narrator.cold_open(w, c))
		texts.append(CaseEngine.discovery_text(w, c))
		texts.append(Narrator.title(w, c))
		var bot = Bot.new(wc[2])
		var d: RefCounted = bot.det
		# scene prose
		bot.examine_scene()
		var pl = load("res://scripts/detective/places.gd").profile(c)
		variety["scene_type"][pl["type"]] = int(variety["scene_type"].get(pl["type"], 0)) + 1
		var plan: Dictionary = bot.solve()
		var res := {"result": Helpers.judged(wc[2], plan)}
		for eid in d.order:
			texts.append(String(d.known[eid]["text"]))
		for st in d.statements:
			texts.append(String(st["text"]))
		for b in ["first_scene", "odd_detail", "lie_caught", "footage", "turn"]:
			var bt: Dictionary = Narrator.beat(b, w, c, d)
			if not bt.is_empty():
				texts.append(String(bt["text"]))
		texts.append(String(res["result"]["text"]))
		# the sheet, the hunch, the dossier, the trails, a night watch: the newer prose
		var gx: RefCounted = DetectiveGame.new(s)
		var bx = Bot.new(gx)
		var px: Dictionary = bx.solve()
		bx.fill_sheet(px)
		var chk: Dictionary = gx.sheet_check()
		for gid in chk["lines"]:
			texts.append(String(chk["lines"][gid]["text"]))
		texts.append(String(gx.sheet_hunch()["text"]))
		texts.append(String(gx.sheet_test_theory()["text"]))
		for tr in gx.trails():
			texts.append(String(tr["text"]))
		var fam: Array = gx.family_circle()
		if not fam.is_empty():
			texts.append(String(gx.remember_them(String(fam[0]["id"]))["text"]))
			texts.append(String(gx.tell_family(String(fam[0]["id"]), ["direct", "gentle", "ask"][s % 3])["text"]))
		texts.append(gx.carrying())
		if not gx.persons_of_interest().is_empty():
			texts.append(String(gx.stakeout(String(gx.sim.people[gx.persons_of_interest()[0]].home), 1)["text"]))
		var ep: Dictionary = Narrator.episode(w, c, d, res["result"])
		texts.append(String(ep["text"]))
		# wrong accusations and the other verdicts' prose
		var innocent := ""
		for x in c["suspects"]:
			if x != c["killer"]:
				innocent = x
		texts.append(String(CaseOps.judge(w, c, Detective.new(), innocent, "money", "blunt")["text"]))
		# the no-evidence interview of a random bystander: stock answers
		var bystander: String = CaseEngine.neighbors(w, c["scene"], 12, c["suspects"] + [c["victim"]])[7]
		var dd := Detective.new()
		var a1: Dictionary = CaseOps.ask(w, c, dd, bystander, "alibi")
		var a2: Dictionary = CaseOps.ask(w, c, dd, bystander, "saw")
		var a3: Dictionary = CaseOps.ask(w, c, dd, bystander, "alibi")
		texts.append(String(a1["text"]))
		texts.append(String(a2["text"]))
		variety["alibi_default"][String(a1["text"])] = true
		variety["saw_none"][String(a2["text"])] = true
		variety["repeat"][String(a3["text"])] = true
		variety["claim_killer"][String(c["profiles"][c["killer"]]["claim"])] = true
		variety["unease"][String(c["clues"]["c_unease"]["text"])] = true
		variety["diary"][String(c["clues"]["c_diary"]["text"])] = true
		variety["dropped"][String(c["clues"]["c_dropped"]["text"])] = true
		variety["open_line"][Narrator.cold_open(w, c).substr(0, 60)] = true
		variety["weather"][Narrator.weather_line(w, c)] = true
		variety["motive"][c["motive"]] = int(variety["motive"].get(c["motive"], 0)) + 1
		variety["method"][c["method"]] = int(variety["method"].get(c["method"], 0)) + 1
		var ns: int = (c["suspects"] as Array).size()
		variety["suspects"][ns] = int(variety["suspects"].get(ns, 0)) + 1
		if c.get("hidden", {}).size() > 0: counts["hidden"] += 1
		if c["clues"].has("c_planted"): counts["planted"] += 1
		if c.has("liar"): counts["liar"] += 1
		if c["profiles"].values().any(func(p): return p.get("role", "") == "decoy"): counts["decoy"] += 1
		if c.get("cameras", []).any(func(cam): return absi(int(cam["offset"])) >= 25): counts["far_clock"] += 1
		for t in texts:
			total_texts += 1
			for pr in Lib.problems(String(t)):
				bad[pr] = int(bad.get(pr, 0)) + 1
				if int(bad[pr]) <= 1:
					print("  seed %d: %s" % [s, pr])
	print("== %d seeds, %d texts, %d distinct problems" % [n, total_texts, bad.size()])
	for k in bad:
		print("   x%d  %s" % [bad[k], k])
	print("== variety")
	for k in variety:
		var v: Dictionary = variety[k]
		if v.size() <= 8:
			print("   %s: %s" % [k, v])
		else:
			print("   %s: %d distinct" % [k, v.size()])
	print("   counts: %s" % [counts])
	quit(0)
