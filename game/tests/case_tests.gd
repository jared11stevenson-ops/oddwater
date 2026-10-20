extends SceneTree
## godot --headless --path game -s tests/case_tests.gd : every case the engine writes is fair, checkable and solvable.

const World = preload("res://scripts/sim/sim_world.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
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
	var t0 := Time.get_ticks_msec()
	var solved := 0
	var lazy_failed := 0
	var wrong_ok := 0
	var N := 24
	var motives: Dictionary = {}
	var methods: Dictionary = {}
	var kinds: Dictionary = {}
	for s in range(1, N + 1):
		var wc: Array = make(s)
		var w: RefCounted = wc[0]
		var c: Dictionary = wc[1]
		motives[c["motive"]] = true
		methods[c["method"]] = true
		kinds[c["scene_kind"]] = true
		# ---- structure
		var v: String = c["victim"]; var k: String = c["killer"]
		var sus: Array = c["suspects"]
		var problems: Array = []
		if not w.people[v].dead: problems.append("victim not dead")
		if not w.alive(w.people[k]): problems.append("killer not alive")
		if v == k: problems.append("victim is killer")
		if sus.size() < 3 or sus.size() > 6 or sus.has(v): problems.append("suspects wrong: %s" % [sus])
		var uniq: Dictionary = {}
		for x in sus: uniq[x] = true
		if uniq.size() != sus.size(): problems.append("duplicate suspects")
		if not sus.has(k): problems.append("killer not a suspect")
		for fid in c["facts"]:
			for kn in c["facts"][fid]["knowers"]:
				if not w.people.has(kn) or kn == v or not w.alive(w.people[kn]):
					problems.append("fact %s has bad knower %s" % [fid, kn])
		for cid in c["clues"]:
			if not CaseEngine.Brief.layout().by_id.has(c["clues"][cid]["lot"]):
				problems.append("clue %s at missing lot %s" % [cid, c["clues"][cid]["lot"]])
		if not c["keyholders"].has(k): problems.append("killer has no key")
		ok(problems.is_empty(), "seed %d: well-formed (%s)" % [s, problems])
		# ---- real alibis: the night record and the history agree
		var night_tick := 36 + int((float(c["hour"]) - 24.0) * 2.0)
		ok(w.where_was(k, 0, night_tick) == c["scene"], "seed %d: the killer really was at the scene at the hour" % s)
		var evening_k: String = w.where_was(k, 0, 30)
		ok(evening_k != "" and w.history.has(0), "seed %d: the killer's evening is on record (%s)" % [s, evening_k])
		var h2 := ""
		for x in sus:
			if c["profiles"][x]["alibi"] == "verified":
				h2 = x
		ok(h2 != "" and w.where_was(h2, 0, night_tick) == c["profiles"][h2]["alibi_lot"], "seed %d: the verified alibi is true" % s)
		# ---- determinism
		if s <= 3:
			var again: Array = make(s)
			ok(str(again[1]["victim"]) == str(c["victim"]) and again[1]["killer"] == k and again[1]["method"] == c["method"], "seed %d: deterministic" % s)
		# ---- a thorough detective solves it
		var bot = Bot.new(w, c)
		var r: Dictionary = bot.solve()
		var res: Dictionary = r["result"]
		if r["accused"] == k and res["verdict"] == "convicted":
			solved += 1
		else:
			print("  unsolved seed %d: accused %s (killer %s) verdict %s cats %d total %d notebook %s" % [s, r["accused"], k, res["verdict"], res["cats"], res["total"], bot.det.order])
		# ---- a lazy one does not
		var w2: Array = make(s)
		var lazy = Bot.new(w2[0], w2[1])
		var lr: Dictionary = lazy.lazy()
		if lr["result"]["verdict"] != "convicted":
			lazy_failed += 1
		# ---- a wrong accusation is wrong
		var w3: Array = make(s)
		var innocent: String = ""
		for x in w3[1]["suspects"]:
			if x != w3[1]["killer"]:
				innocent = x
		var wr: Dictionary = CaseOps.judge(w3[0], w3[1], Detective.new(), innocent, "money", "blunt")
		if wr["verdict"] == "wrong":
			wrong_ok += 1
	ok(solved == N, "a thorough detective solves every case: %d of %d" % [solved, N])
	ok(lazy_failed == N, "a lazy detective never gets a conviction: %d of %d" % [lazy_failed, N])
	ok(wrong_ok == N, "accusing the wrong person is always wrong: %d of %d" % [wrong_ok, N])
	ok(motives.size() >= 3 and methods.size() >= 3 and kinds.size() == 2, "variety: %d motives, %d methods, %d scene kinds" % [motives.size(), methods.size(), kinds.size()])
	# ---- the RPG gates
	var wc2: Array = make(5)
	var d := Detective.new()
	d.skills["forensics"] = 1
	var ex: Dictionary = CaseOps.examine(wc2[0], wc2[1], d, wc2[1]["scene"], "body")
	ok(d.has("c_body") and not d.has("c_time"), "a low Forensics reads the wound but not the time of death")
	d.skills["forensics"] = 2
	CaseOps.examine(wc2[0], wc2[1], d, wc2[1]["scene"], "body")
	ok(d.has("c_time"), "a point more reads the time too")
	d.stress = 95.0
	ok(d.skill("forensics") == 0, "stress frays skills")
	var home: String = wc2[0].people[wc2[1]["killer"]].home
	ok(CaseOps.examine(wc2[0], wc2[1], Detective.new(), home, "search")["learned"].is_empty(), "you can't search a house without a warrant")
	var d2 := Detective.new()
	ok(not CaseOps.request_warrant(wc2[0], wc2[1], d2, wc2[1]["killer"])["ok"], "a judge won't sign a warrant on nothing")
	ok(d2.gain_xp(300) and d2.level >= 2 and d2.points >= 2 and d2.spend_point("empathy") and d2.skills["empathy"] == 4, "XP levels you up and points raise skills")
	# saving the notebook
	var back: RefCounted = Detective.from_dict(d.to_dict())
	ok(back.has("c_body") and back.skills["forensics"] == 2, "the notebook survives a save")
	print("  (%d cases generated and worked in %.1fs)" % [N, (Time.get_ticks_msec() - t0) / 1000.0])
	print("case_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
