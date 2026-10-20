extends SceneTree
## godot --headless --path game -s tests/confessor_tests.gd : false confessors: plausible, wrong, exposed by the held-back detail.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Confessor = preload("res://scripts/detective/confessor.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Bot = preload("res://tests/case_bot.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _night(g: RefCounted) -> void:
	g.end_day()
	g.dawn()

## Nights until someone has walked in and confessed (and the case is still open). Returns the confessor id or "".
func _until_confession(g: RefCounted, limit: int) -> String:
	for i in limit:
		_night(g)
		if Serial.active(g.serial) and not Confessor.list(g.case).is_empty():
			return String(Confessor.list(g.case)[-1]["id"])
	return ""

func _initialize() -> void:
	# --- nobody confesses before the news is out
	var g0 := DetectiveGame.new(11, "", true)
	for i in 2:
		_night(g0)
	ok(int(g0.serial.get("confessions", 0)) == 0 and Confessor.list(g0.case).is_empty(), "no false confessions before the third body")
	# --- find a seed where one walks in once the paper has it
	var found := ""
	var g: RefCounted = null
	for sd in [11, 12, 13, 14, 15, 16]:
		g = DetectiveGame.new(sd, "", true)
		found = _until_confession(g, 14)
		if found != "":
			break
	ok(found != "", "after the news, someone confesses")
	if found == "":
		print("confessor_tests: %d checks, %d failed" % [checks, fails])
		quit(1)
		return
	var c: Dictionary = g.case
	var e: Dictionary = Confessor.entry_for(g.det, found)
	ok(c["killer"] != found and found != c["victim"] and g.sim.alive(g.sim.people[found]), "the confessor is a living resident who is not the killer")
	ok(e["kind"] == "confession" and not e["has_detail"] and e["false_confession"] and not e["tested"], "a confession in the notebook, with no held-back detail")
	ok(absf(float(e["said_hour"]) - float(c["hour"])) >= 3.0 and e["said_method"] != c["method"], "the time and the method are checkably wrong")
	ok(not String(e["text"]).contains(String(c["held_back"])), "the signature detail is missing from the story")
	ok(g.today.any(func(t): return String(t).contains("THE COURIER")), "the paper carries it")
	# --- the detective can arrest them; the interview room exposes them
	var ar: Dictionary = g.arrest(found)
	ok(ar["ok"], "a signed confession is probable cause to arrest")
	g.interrogate("evidence")
	ok(Confessor.entry_for(g.det, found)["tested"] and Confessor.entry_for(g.det, found).get("unreliable", false), "the first interview runs the held-back test and the story fails it")
	ok(g.det.proof_against(found)["exonerate"] >= 3, "the notebook now clears them")
	# --- the same test on demand, without an arrest
	var gb: RefCounted = DetectiveGame.new(g.seed_v, "", true)
	var found2 := _until_confession(gb, 14)
	ok(found2 != "", "same seed, same confessor")
	var chk: Dictionary = gb.check_confession(found2)
	ok(chk["exposed"] and String(chk["text"]).length() > 40, "checking the confession against the scene exposes it")
	ok(not Justice.arrest(gb.sim, gb.case, gb.det, gb.court, found2)["ok"], "no one is arrested on a story that has failed the test")
	# --- a conviction on an untested false confession costs and lets the killer strike again
	var gw := DetectiveGame.new(g.seed_v, "", true)
	var fw := _until_confession(gw, 14)
	var rep0: int = gw.det.reputation["town"]
	var sher0: int = gw.det.reputation["sheriff"]
	var ar2: Dictionary = gw.arrest(fw)
	ok(ar2["ok"], "arrest the confessor (no test)")
	# skip the interview: the trial is the next thing that happens
	gw.court["trial_day"] = int(gw.sim.day)
	var tr: Dictionary = Justice.trial(gw.sim, gw.case, gw.det, fw)
	ok(tr["verdict"] == "guilty" and tr["wrongful"], "an untested confession convicts the wrong person (confidence %d)" % int(tr["confidence"]))
	var res: Dictionary = gw.run_trial()
	ok(res["verdict"] == "guilty" and res["wrongful"], "the trial returns a wrongful verdict")
	ok(gw.det.reputation["town"] < rep0 and gw.det.reputation["sheriff"] < sher0, "reputation falls: town %d -> %d, sheriff %d -> %d" % [rep0, gw.det.reputation["town"], sher0, gw.det.reputation["sheriff"]])
	ok(gw.sim.people[fw].jailed and gw.inmate(fw).get("guilty", true) == false, "an innocent is in the jail")
	ok(int(gw.serial.get("emboldened", 0)) == 1 and gw.paper().any(func(p): return String(p["head"]).contains("OWN WORD")), "the paper reports the scandal and the killer is emboldened")
	var kills0: int = (gw.serial["kills"] as Array).size()
	_night(gw)
	ok((gw.serial["kills"] as Array).size() == kills0 + 1 and gw.case["killer"] == gw.serial["killer"], "the killer strikes again that very night")
	var gp: float = gw.pressure()
	ok(Serial.active(gw.serial) and gp > 0.0, "the hunt goes on, pressure %d" % int(gp))
	# --- the tested version exonerates: the jury will not convict
	var gx := DetectiveGame.new(g.seed_v, "", true)
	var fx := _until_confession(gx, 14)
	gx.check_confession(fx)
	var trx: Dictionary = Justice.trial(gx.sim, gx.case, gx.det, fx)
	ok(trx["verdict"] != "guilty", "once exposed, the confession cannot convict (%s, %d)" % [trx["verdict"], int(trx["confidence"])])
	# --- and an exposed false confession does not hurt the case against the real killer; an untested one does
	var gy := DetectiveGame.new(g.seed_v, "", true)
	var fy := _until_confession(gy, 14)
	var killer: String = gy.case["killer"]
	var bot = Bot.new(gy.sim, gy.case, gy.det)
	bot.solve()
	ok(Confessor.entry_for(gy.det, fy).get("tested", false), "the bot tests every confession")
	var judged: Dictionary = CaseOps.judge(gy.sim, gy.case, gy.det, killer, gy.case["motive"], gy.case["method"])
	ok(judged["verdict"] == "convicted", "a thorough detective still proves the real case: %s" % judged["verdict"])
	var gz := DetectiveGame.new(g.seed_v, "", true)
	_until_confession(gz, 14)
	var bz = Bot.new(gz.sim, gz.case, gz.det)
	for s in gz.case["suspects"]:
		bz.interview(s)
	bz.examine_scene()
	var base: float = float(Justice.trial(gz.sim, gz.case, gz.det, gz.case["killer"])["confidence"])
	var cf_id: String = Confessor.list(gz.case)[-1]["id"]
	Confessor.test(gz.sim, gz.case, gz.det, cf_id)
	ok(float(Justice.trial(gz.sim, gz.case, gz.det, gz.case["killer"])["confidence"]) >= base + 8.0, "an untested confession is the defence's alternative; exposing it takes that away")
	# --- the lazy detective still fails
	var gl := DetectiveGame.new(g.seed_v, "", true)
	_until_confession(gl, 14)
	var lz: Dictionary = Bot.new(gl.sim, gl.case, gl.det).lazy()
	ok(lz["result"]["verdict"] != "convicted", "the lazy bot still fails with a confessor in town (%s)" % lz["result"]["verdict"])
	# --- a confessor's cap, save and load
	var gs := DetectiveGame.new(g.seed_v, "", true)
	_until_confession(gs, 14)
	gs.save("user://confessor_test.json")
	var l: RefCounted = DetectiveGame.load_detective("user://confessor_test.json")
	ok(l != null and not Confessor.list(l.case).is_empty() and Confessor.entry_for(l.det, Confessor.list(l.case)[-1]["id"]).has("said_hour"), "a saved game remembers who confessed")
	var capped := DetectiveGame.new(g.seed_v, "", true)
	for i in 30:
		_night(capped)
	ok(int(capped.serial.get("confessions", 0)) <= Confessor.MAX_PER_SERIAL, "no more than %d per killer" % Confessor.MAX_PER_SERIAL)
	# --- every forced-serial seed in serial_tests still solves with a confessor present
	for sd in [110, 120, 101]:
		var gq := DetectiveGame.new(sd, "", true)
		var fq := _until_confession(gq, 14)
		if fq == "":
			continue
		var bq = Bot.new(gq.sim, gq.case, gq.det)
		var br: Dictionary = bq.solve()
		ok(br["result"]["verdict"] == "convicted" or br["accused"] != gq.case["killer"], "seed %d: solvable with a confessor in the notebook (%s)" % [sd, br["result"]["verdict"]])
	print("confessor_tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
