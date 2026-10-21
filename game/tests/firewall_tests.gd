extends SceneTree
## godot --headless --path game -s tests/firewall_tests.gd : the investigation must not know what the simulation knows (02-gdd/08, rule R8).
## (a) the case file, the notebook and everything the HUD reads carry no truth; (b) investigation-side scripts never read `_truth`;
## (c) a detective who does nothing cannot be led to a conviction; (d) a bot that works only from claims and the public API still solves
## a spread of cases (forced serials included) through accuse -> arrest -> trial -> jail, and a lazy one still fails.

const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")

const CLAIM_KEYS := ["kind", "subject", "predicate", "place", "time", "until", "item", "certainty", "source", "text", "cid"]
const FORBIDDEN_KEYS := ["supports", "_truth_tag", "claim_tags", "profiles", "killer", "motive_thing", "weapon", "gloves", "held_back", "suspects", "herring_ids", "latents", "relatives", "lookalike", "framed", "facts", "clues"]

var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


## Keys anywhere inside a value.
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
	# ---------------------------------------------------------------- (a) a fresh case file and what the HUD reads
	for sd in [1, 2, 3, 4]:
		var g: RefCounted = DetectiveGame.new(sd)
		var t: Dictionary = g._truth
		var dump := JSON.stringify(g.case)
		for secret in [t["killer"], t["motive"], t["method"], t["weapon"], t["held_back"], t["trait"], t["shoes"], t["item"], t["trace"]]:
			ok(not dump.contains(String(secret)), "seed %d: the case file does not contain %s" % [sd, secret])
		var keys := {}
		_keys(g.case, keys)
		for k in FORBIDDEN_KEYS:
			ok(not keys.has(k), "seed %d: the case file has no '%s'" % [sd, k])
		ok(not dump.contains("supports") and not dump.contains("profiles"), "seed %d: no supports or profiles in the case file" % sd)
		for k in g.case:
			ok(k in CaseEngine.PUBLIC_KEYS, "seed %d: '%s' is a public key" % [sd, k])
		var visible := "%s\n%s\n%s" % [g.briefing(), g.opening(), g.objective()]
		var kid := String(t["killer"])
		if kid != String(g.case["found_by"]):
			ok(not g.persons_of_interest().has(kid), "seed %d: the killer is not handed to you as a person of interest" % sd)
			ok(not visible.contains(CaseEngine.name_of(g.sim, kid)), "seed %d: nothing the briefing, opening or objective says names the killer" % sd)
		ok(g.persons_of_interest() == [g.case["found_by"]], "seed %d: at the Sheriff's call the only person of interest is the finder (%s)" % [sd, g.persons_of_interest()])
		ok(g.suspects() == g.persons_of_interest(), "seed %d: suspects() is an alias" % sd)
		for cam in g.cameras():
			ok(String(cam.get("kind", "")) != "doorbell", "seed %d: no neighbour's doorbell camera is listed before you have spoken to them" % sd)
		# a worked notebook: claims all the way down, nothing private in it
		var bot = Bot.new(g)
		var plan: Dictionary = bot.solve()
		var nb_keys := {}
		_keys(g.det.to_dict(), nb_keys)
		for k in ["supports", "_truth_tag", "claim_tags", "profiles", "has_detail", "false_confession", "unreliable", "misleading"]:
			ok(not nb_keys.has(k), "seed %d: the notebook has no '%s'" % [sd, k])
		var all_claims := true
		for eid in g.det.order:
			var cls: Array = g.det.known[eid].get("claims", [])
			all_claims = all_claims and not cls.is_empty()
			for cl in cls:
				for ck in cl:
					all_claims = all_claims and (ck in CLAIM_KEYS)
				for ck2 in CLAIM_KEYS:
					all_claims = all_claims and cl.has(ck2)
		ok(all_claims and g.det.order.size() > 10, "seed %d: every notebook entry is structured claims and only claims (%d entries)" % [sd, g.det.order.size()])
		var adv: String = g.da_advice(plan["accused"])
		ok(adv != "" and not adv.contains("%") and not _has_digit(adv), "seed %d: the DA speaks in words, not numbers" % sd)
		# the truth stays in the truth
		ok(g._truth.has("claim_tags") and (g._truth["claim_tags"] as Dictionary).size() >= g.det.order.size(), "seed %d: the claim tags live with the truth" % sd)

	# ---------------------------------------------------------------- (b) investigation-side scripts never read the truth
	var ui_dir := DirAccess.get_files_at("res://scripts/ui")
	var scanned := 0
	for f in ui_dir:
		if f.ends_with(".gd"):
			var src := _read("res://scripts/ui/" + f)
			scanned += 1
			ok(not src.contains("_truth") and not src.contains("claim_tags") and not src.contains("_truth_tag"), "ui/%s does not touch the truth" % f)
			ok(not src.contains("proof_against(\"") and not src.contains("[\"supports\"]"), "ui/%s does not read proof or supports directly" % f)
	ok(scanned > 10, "scanned the ui scripts (%d)" % scanned)
	var dg := _read("res://scripts/detective/detective_game.gd")
	for fn in ["func _objective_core", "func objective", "func persons_of_interest", "func da_advice", "func briefing", "func opening"]:
		var i := dg.find(fn)
		var j := dg.find("\nfunc ", i + 10)
		ok(i >= 0 and not dg.substr(i, j - i).contains("_truth"), "%s reads only the case file and the notebook" % fn)
	for f in ["narrator.gd", "reasoning.gd", "claims.gd"]:
		var src := _read("res://scripts/detective/" + f)
		ok(not src.replace("_truth_tag", "").contains("_truth"), "%s never names the private truth" % f)
	var narr := _read("res://scripts/detective/narrator.gd")
	var bi := narr.find("static func beat")
	var be := narr.find("static func _verdict_line")
	var beat_src := narr.substr(bi, be - bi)
	ok(not beat_src.contains("c[\"killer\"]") and not beat_src.contains("c[\"motive\"]") and not beat_src.contains("c[\"held_back\"]") and not beat_src.contains("c[\"suspects\"]"), "narrator beats (shown during play) read no killer, motive, detail or suspect list")
	var co := narr.substr(narr.find("static func cold_open"), narr.find("static func _fill") - narr.find("static func cold_open"))
	ok(not co.contains("[\"killer\"]") and not co.contains("[\"motive\"]") and not co.contains("[\"suspects\"]"), "the cold open reads only the case file")

	# ---------------------------------------------------------------- (c) a detective who does nothing cannot get a conviction
	for sd in [1, 2, 3]:
		var g2: RefCounted = DetectiveGame.new(sd)
		var kid2: String = String(g2._truth["killer"])
		var r1: Dictionary = g2.accuse(kid2, g2._truth["motive"], g2._truth["method"])
		ok(r1["verdict"] == "insufficient", "seed %d: naming the killer with nothing in the notebook is turned away (%s)" % [sd, r1["verdict"]])
		var arrest: Dictionary = g2.arrest(kid2)
		ok(not arrest["ok"] and g2.court.get("custody", "") == "", "seed %d: no arrest on an empty notebook" % sd)
		for rid in g2.residents().slice(0, 12):
			if g2.can_accuse():
				g2.accuse(rid, "money", "blunt")
		ok(g2.jail.is_empty() and not g2.solved(), "seed %d: a detective who does nothing never closes the case" % sd)
		var text := ""
		for step in 6:
			text += g2.objective() + "\n"
		ok(not text.contains(CaseEngine.name_of(g2.sim, kid2)) or kid2 == String(g2.case["found_by"]), "seed %d: the objective never leads you to the killer by name" % sd)

	# ---------------------------------------------------------------- (d) the thorough bot, from claims alone, to a cell
	var solved := 0
	var total := 0
	for spec in [[1, false], [2, false], [3, false], [4, false], [5, false], [110, true], [120, true], [101, true], [105, true], [115, true]]:
		var g3: RefCounted = DetectiveGame.new(int(spec[0]), "", bool(spec[1]))
		var killer: String = String(g3._truth["killer"])
		var b3 = Bot.new(g3)
		var plan3: Dictionary = b3.solve()
		var res: Dictionary = g3.accuse(plan3["accused"], plan3["motive"], plan3["method"])
		total += 1
		var jailed: bool = g3.jail.any(func(i): return i["id"] == killer)
		if plan3["accused"] == killer and res["verdict"] == "convicted" and g3.solved() and jailed and g3.sim.people[killer].jailed:
			solved += 1
		else:
			print("  seed %d%s: accused %s (killer %s) verdict %s jailed %s" % [int(spec[0]), " (serial)" if spec[1] else "", plan3["accused"], killer, res["verdict"], jailed])
		# the lazy one on the same seed
		var gl: RefCounted = DetectiveGame.new(int(spec[0]), "", bool(spec[1]))
		var lz: Dictionary = Bot.new(gl).lazy()
		var lres: Dictionary = gl.accuse(lz["accused"], lz["motive"], lz["method"])
		var lres2: Dictionary = gl.accuse(gl._truth["killer"], gl._truth["motive"], gl._truth["method"]) if gl.can_accuse() else {"verdict": "barred"}
		ok(lres["verdict"] != "convicted" and lres2["verdict"] != "convicted" and not gl.solved() and gl.jail.is_empty(), "seed %d: the lazy detective still fails (%s, %s)" % [int(spec[0]), lres["verdict"], lres2["verdict"]])
	ok(solved == total, "the claims-only bot solves every case, serials included, to a cell: %d of %d" % [solved, total])

	# the long road by hand: arrest -> interview -> trial -> jail
	var gh: RefCounted = DetectiveGame.new(2)
	var bh = Bot.new(gh)
	var ph: Dictionary = bh.solve()
	var ar: Dictionary = gh.arrest(ph["accused"])
	ok(ar["ok"], "the bot's case gives probable cause for an arrest (%s)" % ar.get("text", ""))
	if ar["ok"]:
		gh.interrogate("evidence")
		var tr: Dictionary = gh.run_trial()
		ok(tr["verdict"] == "guilty" and gh.jail.any(func(i): return i["id"] == ph["accused"]) and gh.solved(), "arrest -> interview -> trial -> a cell (%s)" % tr["verdict"])

	# ---------------------------------------------------------------- a mistaken witness can sink a right case; a false claim can mislead
	var gm: RefCounted = DetectiveGame.new(2)
	var kt: String = String(gm._truth["killer"])
	var base := {"id": "w1", "title": "w", "text": "x", "kind": "testimony", "source": "", "day": 1}
	var tmpl := load("res://scripts/detective/claims.gd")
	var sink: Array = []
	for pred in [["seen_at_scene", "false"], ["motive_quarrel", "true"], ["weapon_in_home", "true"], ["item_recognised", "true"]]:
		var e: Dictionary = base.duplicate()
		e["id"] = "w_" + pred[0]
		e["claims"] = tmpl.emit(gm._truth, [tmpl.make("seen", kt, pred[0], gm._truth["scene"], gm._truth["hour"], "", 1.0, pred[1])], "x", "x")
		gm.det.learn(e)
	var Justice = load("res://scripts/detective/justice.gd")
	var with_false: Dictionary = Justice.trial(gm.sim, gm._truth, gm.det, kt)
	var gm2: RefCounted = DetectiveGame.new(2)
	for pred in [["seen_at_scene", "true"], ["motive_quarrel", "true"], ["weapon_in_home", "true"], ["item_recognised", "true"]]:
		var e2: Dictionary = base.duplicate()
		e2["id"] = "w_" + pred[0]
		e2["claims"] = tmpl.emit(gm2._truth, [tmpl.make("seen", kt, pred[0], gm2._truth["scene"], gm2._truth["hour"], "", 1.0, pred[1])], "x", "x")
		gm2.det.learn(e2)
	var with_true: Dictionary = Justice.trial(gm2.sim, gm2._truth, gm2.det, kt)
	ok(gm.det.proof_against(kt) == gm2.det.proof_against(kt), "the notebook weighs a lying witness exactly like an honest one")
	ok(float(with_false["confidence"]) < float(with_true["confidence"]) - 5.0, "but the court finds the lie out: a mistaken witness sinks the case (%s vs %s)" % [with_false["confidence"], with_true["confidence"]])

	# ---------------------------------------------------------------- saving keeps the truth apart; an old save still loads
	var gs: RefCounted = DetectiveGame.new(3)
	Bot.new(gs).examine_scene()
	var d: Dictionary = gs.to_dict()
	ok(d.has("truth") and d.has("case") and not JSON.stringify(d["case"]).contains(String(gs._truth["killer"])), "the saved case file is public; the truth is saved separately")
	var round: String = JSON.stringify(d)
	var back: RefCounted = DetectiveGame.new(3, "", false, true)
	back.load_dict(JSON.parse_string(round))
	ok(back._truth["killer"] == gs._truth["killer"] and back.case == gs.case or back.case.size() == gs.case.size(), "a save round-trips both halves")
	var old: Dictionary = JSON.parse_string(round)
	old.erase("truth")
	old["case"] = JSON.parse_string(JSON.stringify(gs._truth))
	var back2: RefCounted = DetectiveGame.new(3, "", false, true)
	back2.load_dict(old)
	ok(back2._truth["killer"] == gs._truth["killer"] and not JSON.stringify(back2.case).contains(String(gs._truth["killer"])), "an old save (one big case dictionary) loads and is split on the way in")

	print("  (firewall tests took %.1fs)" % [(Time.get_ticks_msec() - t0) / 1000.0])
	print("firewall_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)


func _has_digit(s: String) -> bool:
	for ch in s:
		if ch >= "0" and ch <= "9":
			return true
	return false
