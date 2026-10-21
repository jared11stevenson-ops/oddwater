extends "res://scripts/sim/town_game.gd"
## The detective game: the town sim with you as its detective. A murder has already happened the night before the story starts;
## you wake on Day 1 at your own front door with the Sheriff's call. No swapping: you are always you.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const News = preload("res://scripts/detective/news.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Confessor = preload("res://scripts/detective/confessor.gd")
const Cold = preload("res://scripts/detective/cold.gd")
const Life = preload("res://scripts/detective/life.gd")
const Places = preload("res://scripts/detective/places.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")

const ACCUSE_LIMIT := 3

const DET_SAVE := "user://detective_save.json"

var det: RefCounted
## The CASE FILE: what the Sheriff's call and the first scene give a detective, and nothing else (see CaseEngine.PUBLIC_KEYS). Everything the
## investigation shows the player is built from this and the notebook.
var case: Dictionary = {}
## The simulation's private truth: killer, motive, method, the real night, every secret and every claim's hidden tag. Only the emitters
## (CaseOps, Cctv, Prints, Confessor, Justice, Serial, Cold) and the adjudicator receive it; the investigation never reads it.
var _truth: Dictionary = {}
var _minutes := 0
var court: Dictionary = {"custody": ""}     # who is in custody, the trial day, the interview-room state
var jail: Array = []                         # the convicted (and the wrongly convicted): the Gallery
var beats_seen: Dictionary = {}
var pending_beats: Array = []       # narrated interludes waiting to be shown
var episodes: Array = []            # the told stories of cases you have worked
var seed_v := 1961
var serial: Dictionary = {}         # the serial killer, if there is one (see serial.gd)
var _force_serial := false
var past_signatures: Array = []     # every serial killer leaves a sign of their own
var newcomers: Array = []           # the residents who have moved in since the story began (their data, so a save brings them back)
var _arrivals: Array = []
var haunting: Dictionary = {}       # a killer who got away: {killer, nick, signature, since, cases}
var repeat_killer := ""             # a killer of a cold case who will strike again
var business: Array = []            # ordinary town business (small cases), open and closed
var town_news: Array = []           # front pages that are not about a serial killer (scandals, cold files)


## The town grows: two days after a case is fully solved, someone new moves in.
func _welcome_newcomer() -> void:
	var d: Dictionary = sim.make_newcomer(newcomers.size() + 1)
	newcomers.append(d)
	_arrivals.append("%s, %d, %s, has moved into %s." % [d["name"], int(d["age"]), Prose.job_np(String(d["job"])), place_name(d["home"])])
	chronicle.append({"day": sim.day, "text": "%s moved to Little Mercy." % d["name"]})


## `force_serial` makes the first murder the work of a serial killer (tests; a rare thing in real play).
func _init(seed_value: int = 1961, _first_host: String = "", force_serial: bool = false, skip_prelude: bool = false) -> void:
	super._init(seed_value, "player")
	seed_v = seed_value
	_force_serial = force_serial
	det = Detective.new()
	serial = Serial.none()
	sim.release_control()
	if not skip_prelude:
		_prelude(seed_value)
	hosts = []
	wake("player")
	wishes = []
	talk_costs_time = false


func _pick_host() -> String:
	return "player"


## The night before the story: a day is lived and a murder happens in the dark. History and the night record are real.
func _prelude(seed_value: int) -> void:
	sim.day = 0
	sim.thin_weeks = false
	sim.start_day()
	var opt := {}
	if _force_serial or Serial.rolls(seed_value, "start"):
		serial = Serial.begin(sim, seed_value, "start", past_signatures)
		past_signatures.append(serial["signature"])
		opt = Serial.opts(serial)
	_truth = CaseEngine.generate(sim, seed_value, 0, opt)
	CaseEngine.apply_backstory(sim, _truth)
	sim.simulate_rest_of_day()
	CaseEngine.execute(sim, _truth)
	if Serial.active(serial):
		Serial.record(sim, serial, _truth, seed_value, place_name(_truth["scene"]))
	_sync_case()
	sim.slack()
	sim.start_day()
	_seen_events = 0


func briefing() -> String:
	return CaseEngine.discovery_text(sim, case)


func opening() -> String:
	return Narrator.cold_open(sim, case)


## The case file is the public face of the truth: copy across only what a detective may know, and tell the notebook what the town's trades are.
func _sync_case() -> void:
	case = CaseEngine.public_file(_truth)
	var jobs := {}
	for id in sim.order:
		jobs[id] = String(sim.people[id].job)
	det.ctx = {"case": case, "jobs": jobs}


## After anything you do: has the story reached a moment worth telling?
func _after_op() -> void:
	_sync_case()
	for kind in ["first_scene", "odd_detail", "lie_caught", "footage", "turn"]:
		if beats_seen.has(kind):
			continue
		var b: Dictionary = Narrator.beat(kind, sim, case, det)
		if not b.is_empty():
			beats_seen[kind] = true
			pending_beats.append(b)


func take_beat() -> Dictionary:
	return pending_beats.pop_front() if not pending_beats.is_empty() else {}


func scene_lot() -> String:
	return case.get("scene", "")


## Time spent on an investigation task. Minutes build up while you are in a panel (the town holds its breath so nobody wanders off
## mid-sentence); call flush_time() when you step away and the town moves on by however many half hours you used.
func spend(minutes: int) -> int:
	_minutes += minutes
	return 0


func flush_time() -> int:
	var ticks := 0
	while _minutes >= 30 and not sim.day_over() and phase == "day":
		_minutes -= 30
		realtime_tick(me().location, false)
		ticks += 1
	return ticks


## The next sensible thing to do, from what you know. Never gives the answer, only the next thread to pull.
func objective() -> String:
	var core := _objective_core()
	if Serial.active(serial) and Serial.days_left(serial, int(sim.day)) >= 0:
		return "%s  [%s: %d days. Pressure %d]" % [core, String(serial["nick"]), Serial.days_left(serial, int(sim.day)), int(pressure())]
	return core


func _objective_core() -> String:
	var st: String = case.get("status", "")
	var v: String = case.get("victim", "")
	var vn := CaseEngine.name_of(sim, v) if v != "" else "the dead"
	if st == "solved":
		return _quiet_objective("Case closed.")
	if st == "cold":
		return _quiet_objective("The file on %s has gone cold. Someone is still out there." % vn)
	if st == "fled":
		return _quiet_objective("The killer of %s has fled Little Mercy. The file stays open somewhere else." % vn)
	if st == "failed":
		return _quiet_objective("Reassigned: the state police have the file on %s. Keep the town's small troubles from becoming large ones." % vn)
	if court.get("custody", "") != "":
		var tn := CaseEngine.name_of(sim, court["custody"])
		if trial_ready():
			return "%s's trial is today. Make sure everything you have is in order." % tn
		return "%s is in custody. Question them before the trial on day %d." % [tn, int(court.get("trial_day", 0))]
	if not det.has("c_body"):
		return "Examine the crime scene: %s." % place_name(scene_lot())
	var asked := {}
	for st2 in det.statements:
		asked[st2["npc"]] = true
	if not asked.has(case.get("found_by", "")):
		return "Question %s, who found the body." % CaseEngine.name_of(sim, case["found_by"])
	var unasked: Array = persons_of_interest().filter(func(s): return not asked.has(s))
	if not unasked.is_empty():
		return "Talk to the people your notes name. Next: %s." % CaseEngine.name_of(sim, unasked[0])
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		if e.get("lab", false) and not det.has("lab_" + eid) and not det.lab.any(func(l): return l.get("clue", "") == eid):
			return "Send \"%s\" to the lab." % String(e["title"]).to_lower()
	if det.known.size() < 8:
		return "Canvass the neighbours of the scene and of the people in your notes."
	if accusations_left() <= 1:
		return "You have one formal accusation left. Be certain."
	if Cold.days_open(self) >= 5:
		return "The trail is cooling (%d days). Evidence is spoiling and witnesses are forgetting. Decide." % Cold.days_open(self)
	return "Look for what contradicts what you have been told. Then decide."


func _quiet_objective(prefix: String) -> String:
	for b in business:
		if b["status"] == "open":
			return "%s Meanwhile: %s" % [prefix, b["title"]]
	return prefix + " Rest, and watch the town."


func spots(lot: String) -> Array:
	return CaseOps.spots_at(sim, _truth, lot)


func examine(lot: String, spot: String) -> Dictionary:
	var r: Dictionary = CaseOps.examine(sim, _truth, det, lot, spot)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func ask(npc: String, topic: String, about: String = "") -> Dictionary:
	var r: Dictionary = CaseOps.ask(sim, _truth, det, npc, topic, about)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func present(npc: String, entry_id: String) -> Dictionary:
	var r: Dictionary = CaseOps.present(sim, _truth, det, npc, entry_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


## The cameras you know about: the town's, and a neighbour's doorbell camera once you have spoken to its owner.
func cameras() -> Array:
	var asked := {}
	for st in det.statements:
		asked[st["npc"]] = true
	return Cctv.cameras(_truth).filter(func(cam): return String(cam.get("kind", "")) != "doorbell" or asked.has(cam.get("owner", "")))


func camera(cam_id: String) -> Dictionary:
	return Cctv.camera(_truth, cam_id)


## The surfaces at the scene worth dusting.
func dust_spots() -> Array:
	return ["door", "phone", "desk", "floor", "garden"]


func view_camera(cam_id: String, from_h: float, to_h: float) -> Dictionary:
	var r: Dictionary = Cctv.view(sim, _truth, det, cam_id, from_h, to_h, persons_of_interest())
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func calibrate_camera(cam_id: String) -> Dictionary:
	var r: Dictionary = Cctv.calibrate(sim, _truth, det, cam_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func dust(lot: String, spot: String) -> Dictionary:
	var r: Dictionary = Prints.dust(sim, _truth, det, lot, spot)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func take_sample(npc: String) -> Dictionary:
	var r: Dictionary = Prints.take_sample(sim, _truth, det, npc)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func compare_print(print_entry: String, target: String) -> Dictionary:
	var r: Dictionary = Prints.submit_compare(sim, _truth, det, print_entry, target)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func submit_lab(clue_id: String) -> Dictionary:
	var r: Dictionary = CaseOps.submit_to_lab(sim, _truth, det, clue_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func warrant(target: String) -> Dictionary:
	var r: Dictionary = CaseOps.request_warrant(sim, _truth, det, target)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func arrest(target: String) -> Dictionary:
	var r: Dictionary = Justice.arrest(sim, _truth, det, court, target)
	_after_op()
	return r


func interrogate(approach: String) -> Dictionary:
	var r: Dictionary = Justice.interrogate(sim, _truth, det, court, approach)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


## Hold a confession up against the scene: the hour, the wound, and the one detail that was never printed.
func check_confession(id: String) -> Dictionary:
	var r: Dictionary = Confessor.test(sim, _truth, det, id)
	r["ticks"] = spend(20)
	_after_op()
	return r


## Someone convicted on a false confession: the killer, watching, takes the chance (the paper says so).
func _false_conviction_check() -> void:
	var t: String = String(_truth.get("false_conviction", ""))
	if t == "" or _truth.get("false_conviction_done", false):
		return
	_truth["false_conviction_done"] = true
	var nm: String = CaseEngine.name_of(sim, t)
	if Serial.active(serial):
		Confessor.convicted_wrongly(serial, int(sim.day))
	var d: Dictionary = Prose.json("detective/confessors.json")
	var page := {"day": int(sim.day), "kind": "scandal", "head": "CONVICTED ON HIS OWN WORD", "body": String(d["jailed_news"]).replace("{n}", nm.to_upper())}
	town_news.append(page)
	today.append(String(d["jailed_news"]).replace("{n}", nm.to_upper()))
	chronicle.append({"day": sim.day, "text": "%s was jailed on a false confession." % nm})


func trial_ready() -> bool:
	return court.get("custody", "") != "" and sim.day >= int(court.get("trial_day", 999))


## The trial: the defence attacks, the jury decides, and the verdict is applied to the town.
func run_trial() -> Dictionary:
	var t: String = court.get("custody", "")
	if t == "":
		return {"verdict": "none", "attacks": [], "confidence": 0}
	var res: Dictionary = Justice.trial(sim, _truth, det, t)
	Justice.conclude(sim, _truth, det, court, jail, res)
	var ep: Dictionary = Narrator.episode(sim, _truth, det, {"verdict": "convicted" if res["verdict"] == "guilty" and not res["wrongful"] else "wrong" if res["verdict"] == "guilty" else "released", "score": int(res["confidence"]), "right_person": t == _truth["killer"]})
	if res["verdict"] in ["guilty", "not guilty"]:
		episodes.append(ep)
		res["episode"] = ep
	chronicle.append({"day": sim.day, "text": "Trial of %s: %s." % [CaseEngine.name_of(sim, t), res["verdict"]]})
	_false_conviction_check()
	_check_caught()
	_sync_case()
	return res


func inmate(id: String) -> Dictionary:
	for i in jail:
		if i["id"] == id:
			return i
	return {}


func visit(id: String, topic: String) -> Dictionary:
	var i: Dictionary = inmate(id)
	if i.is_empty():
		return {"text": "They are not here.", "minutes": 0}
	var r: Dictionary = Justice.visit(sim, _truth, det, i, topic)
	r["ticks"] = spend(int(r["minutes"]))
	return r


func appeal(id: String) -> Dictionary:
	var i: Dictionary = inmate(id)
	if i.is_empty():
		return {"ok": false, "text": "They are not here."}
	return Justice.appeal(sim, _truth, det, jail, i)


func accusations_left() -> int:
	return maxi(ACCUSE_LIMIT - int(_truth.get("accusations", 0)), 0)


func can_accuse() -> bool:
	return _truth.get("status", "") == "open" and accusations_left() > 0


## Name the killer: a formal charge. It runs the one road: judge -> arrest -> interview -> trial -> a cell, with the same reputation ledger
## as the court tab. A right name on a case that holds goes to trial at once; a wrong name costs more each time, and you only get three.
## Returns {verdict, text, score, cats, total, episode, left, ...}.
func accuse(culprit: String, motive: String, method: String) -> Dictionary:
	if not can_accuse():
		return {"verdict": "barred", "text": "The Sheriff will not hear another accusation on this file.", "score": 0, "cats": 0, "total": 0, "left": 0}
	if not sim.people.has(culprit) or culprit == "player" or not sim.alive(sim.people[culprit]) or culprit == String(_truth["victim"]):
		return {"verdict": "barred", "text": "There is no one in Little Mercy by that name to accuse.", "score": 0, "cats": 0, "total": 0, "left": accusations_left()}
	var res: Dictionary = CaseOps.judge(sim, _truth, det, culprit, motive, method)
	_truth["accusations"] = int(_truth.get("accusations", 0)) + 1
	(_truth["accused"] as Array).append(culprit)
	var theory: bool = res["right_motive"] and res["right_method"]
	match String(res["verdict"]):
		"convicted":
			var ch: Dictionary = Justice.formal_charge(sim, _truth, det, court, jail, culprit, theory, true)
			var tr: Dictionary = ch["trial"]
			res["trial"] = tr
			res["interview"] = ch["interview"]
			if tr["verdict"] == "guilty":
				var pk: RefCounted = sim.people[culprit]
				sim.log_event("arrest", culprit, "%s was arrested for the murder of %s." % [pk.display, CaseEngine.name_of(sim, _truth["victim"])])
				res["text"] = Prose.clean(String(res["text"]) + "\n\nCharged, questioned and tried: the jury returns in an hour. Guilty. %s is taken down." % CaseEngine.first(sim, culprit))
			else:
				res["verdict"] = "released"
				res["text"] = "The case reached court and the jury would not convict. %s walks, or is held for a retrial, and knows exactly how close it was." % CaseEngine.name_of(sim, culprit)
				CaseOps.apply_outcome(sim, _truth, det, res, culprit)
		"released":
			Justice.formal_charge(sim, _truth, det, court, jail, culprit, theory, false)
			CaseOps.apply_outcome(sim, _truth, det, res, culprit)
			res["text"] = Prose.clean(String(res["text"]) + " The trial is set for day %d." % int(court.get("trial_day", 0)))
		"wrong":
			CaseOps.apply_outcome(sim, _truth, det, res, culprit)
			if res.get("case_against", false):
				var ch2: Dictionary = Justice.formal_charge(sim, _truth, det, court, jail, culprit, false, true)
				res["trial"] = ch2["trial"]
				if ch2["trial"]["verdict"] == "guilty":
					res["wrongful"] = true
					res["text"] = String(res["text"]) + " The evidence you gathered was enough for a jury. It was wrong. %s is sentenced." % CaseEngine.first(sim, culprit)
			town_news.append({"day": int(sim.day), "kind": "scandal", "head": "WRONGFUL ARREST SCANDAL", "body": res.get("scandal", "")})
			today.append("THE COURIER: %s" % res.get("scandal", ""))
		_:
			CaseOps.apply_outcome(sim, _truth, det, res, culprit)
	_sync_case()
	res["left"] = accusations_left()
	var ep: Dictionary = Narrator.episode(sim, _truth, det, res)
	episodes.append(ep)
	res["episode"] = ep
	chronicle.append({"day": sim.day, "text": "You accused %s: %s." % [CaseEngine.name_of(sim, culprit), res["verdict"]]})
	if _truth.get("status", "") == "open" and accusations_left() == 0 and res["verdict"] != "released":
		_aftermath("spent")
		res["aftermath"] = true
	_false_conviction_check()
	_check_caught()
	_sync_case()
	return res


## The cost of an action before you take it: {minutes, ticks (half hours), label, stress, note}.
func cost_of(action: String, args: Dictionary = {}) -> Dictionary:
	var mins := 0
	var note := ""
	var stress := 0.0
	match action:
		"examine": mins = 15; stress = 6.0 if args.get("spot", "") == "body" else 0.0
		"ask": mins = 6
		"present": mins = 5
		"view_camera": mins = 30
		"calibrate": mins = 10
		"dust": mins = 20
		"sample": mins = 10
		"submit_lab": mins = 15; note = "results tomorrow"
		"warrant": mins = 30
		"interrogate": mins = 60; note = "wears on both of you"
		"check_confession": mins = 20; note = "the hour, the wound and the sign"
		"visit": mins = 30; note = "10 am to 4 pm"
		"funeral": mins = 90; note = "the chapel notices who comes"
		"sermon": mins = 60
		"follow_up": mins = 15
		"accuse": mins = 0; note = "%d formal accusations left; a wrong one costs more each time" % accusations_left()
		"go":
			mins = int(distance(me().location, String(args.get("place", me().location))) / 450.0) * 30
	return {"minutes": mins, "ticks": int(ceil(float(mins) / 30.0)), "label": "%d min" % mins, "stress": stress, "note": note}


# ------------------------------------------------------------------ ordinary life
func town_business() -> Array:
	return business.filter(func(b): return b["status"] == "open")


func follow_up(biz_id: String, npc: String) -> Dictionary:
	for b in business:
		if b["id"] == biz_id:
			var r: Dictionary = Life.follow_up(sim, b, npc)
			r["ticks"] = spend(int(r["minutes"]))
			return r
	return {"text": "No such matter.", "minutes": 0}


func resolve_business(biz_id: String) -> Dictionary:
	for b in business:
		if b["id"] == biz_id and b["status"] == "open":
			if (b["found"] as Array).size() < int(b["need"]):
				return {"ok": false, "text": "You do not know enough yet. Talk to the people who were there."}
			b["status"] = "solved"
			Reputation.apply(det, "business_solved", int(sim.day))
			det.gain_xp(25)
			det.add_stress(-5.0)
			chronicle.append({"day": sim.day, "text": b["title"] + ": settled."})
			return {"ok": true, "text": b["solution"]}
	return {"ok": false, "text": "No such matter."}


func funeral_available() -> bool:
	var d := int(sim.day) - int(case.get("day", 0))
	return d >= 3 and d <= 6 and not det.funerals.get(case.get("id", ""), false) and sim.people.has(case.get("victim", "")) and sim.people[case["victim"]].dead


func attend_funeral() -> Dictionary:
	if not funeral_available():
		return {"ok": false, "text": "There is no funeral to attend.", "minutes": 0}
	det.funerals[case["id"]] = true
	Reputation.apply(det, "funeral", int(sim.day))
	det.add_stress(-5.0)
	# What you see is what anyone could see: three people who behave oddly at a funeral, in an order that tells you nothing. Grief and guilt
	# look alike from the back of a chapel.
	var behaviours: Array = ["stands apart from the others and does not sing", "arrives late and leaves before the last hymn", "keeps checking the door", "weeps without a sound and will not be comforted", "shakes every hand and looks at none of them"]
	var who: Array = []
	var cands: Array = []
	for id in sim.people[case["victim"]].rel:
		if sim.people.has(id) and id != "player" and sim.alive(sim.people[id]) and sim.people[id].group in ["adult", "elder"]:
			cands.append(id)
	cands.sort_custom(func(a, b): return absi(hash("%s|mourner|%s" % [case["id"], a])) < absi(hash("%s|mourner|%s" % [case["id"], b])))
	who = cands.slice(0, 3)
	if who.is_empty():
		who = [String(case["found_by"])]
	var pick := absi(hash("%s|funeral" % case["id"])) % behaviours.size()
	var lines: Array = []
	var tmpl: Array = []
	for i2 in who.size():
		var beh: String = behaviours[(pick + i2 * 2) % behaviours.size()]
		lines.append("%s %s." % [CaseEngine.first(sim, who[i2]), beh])
		tmpl.append(Claims.make("seen", who[i2], "seen_at_funeral", "", -1.0, beh, 0.6))
	lines.sort_custom(func(a, b): return absi(hash(String(a) + String(case["id"]))) < absi(hash(String(b) + String(case["id"]))))
	var text := "The chapel is full and cold. The hymn is one you don't know, and everybody does. At the back: %s" % " ".join(lines)
	var e := {"id": "funeral_" + String(case["id"]), "title": "The funeral", "text": text, "kind": "testimony", "source": "chapel", "day": int(sim.day)}
	e["claims"] = Claims.emit(_truth, tmpl, "chapel", text)
	det.learn(e)
	return {"ok": true, "text": text, "minutes": 90, "ticks": spend(90)}


func attend_sermon() -> Dictionary:
	Reputation.apply(det, "sermon", int(sim.day))
	det.add_stress(-8.0)
	var tier := Reputation.chapel_tier(det)
	var text := "You sit through the sermon. The pastor does not look at you."
	if tier in ["welcome", "trusted"]:
		var lore: Array = Justice.LORE
		var line: String = lore[absi(hash("%s|%d" % [case.get("id", ""), int(sim.day)])) % lore.size()]
		text = "After the service the pastor presses your hand. \"%s\"" % line
		det.learn({"id": "sermon_%d" % int(sim.day), "title": "The pastor's counsel", "text": line, "kind": "lore", "source": "chapel", "day": int(sim.day), "claims": Claims.emit(_truth, [Claims.make("said", "", "lore")], "chapel", line)})
	return {"ok": true, "text": text, "minutes": 60, "ticks": spend(60)}


func paper() -> Array:
	return town_news


## A case ends badly: the state police take it, you are reassigned, and the killer remains in Little Mercy as a thread that will come back.
func _aftermath(kind: String) -> void:
	var killer: String = _truth.get("killer", "")
	_truth["status"] = "failed"
	_truth["closed_day"] = int(sim.day)
	if kind == "spent":
		Reputation.apply(det, "accusations_spent", int(sim.day))
		today.append("The Sheriff takes the file from you. Three names, three mistakes. The state police have it now.")
	if int(serial.get("resumed", 0)) >= 1 and kind == "serial":
		sim.people[killer].taken = true
		sim.people[killer].location = ""
		haunting = {}
		_truth["status"] = "fled"
		today.append("THE COURIER: %s HAS VANISHED. The state police say they are 'following leads'. The chapel bell rang once at noon." % String(serial.get("nick", "THE KILLER")).to_upper())
	else:
		det.rank = "Deputy"
		haunting = {"killer": killer, "nick": serial.get("nick", ""), "signature": serial.get("signature", _truth.get("held_back", "")), "since": int(sim.day), "cases": 0, "kind": kind}
		today.append("REASSIGNED: you are a deputy again, and the town's small troubles are yours. The killer has not left. You know it the way you know a tooth.")
	var ep: Dictionary = Narrator.episode(sim, _truth, det, {"verdict": "failure" if _truth.get("status") == "failed" else "fled", "score": 0, "right_person": false})
	episodes.append(ep)
	chronicle.append({"day": sim.day, "text": "The state police took the case from you."})
	_sync_case()


## Who the notebook gives you a reason to look at: the one who found the body, anyone a claim names, anyone you have questioned or flagged.
## The generator's own cast is not visible from here. (Anyone living in Little Mercy can still be accused.)
func persons_of_interest() -> Array:
	return det.persons_of_interest().filter(func(id): return sim.people.has(id) and sim.alive(sim.people[id]))


## Old callers and tests: a thin alias.
func suspects() -> Array:
	return persons_of_interest()


func flag_person(id: String) -> void:
	if sim.people.has(id):
		det.flag_person(id)


## Every living adult in Little Mercy, for the accusation picker.
func residents() -> Array:
	var out: Array = []
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		if id != "player" and sim.alive(p) and id != String(case.get("victim", "")) and p.group in ["adult", "elder"]:
			out.append(id)
	return out


## What the DA makes of the case against someone: qualitative, from the notebook alone.
func da_advice(person: String) -> String:
	return det.da_read(person, CaseEngine.first(sim, person) if sim.people.has(person) else "")


func solved() -> bool:
	return _truth.get("status", "") == "solved"


## Dawn: the night's work is done (a killer may have struck), the lab reports in, and the town is the same town, one day on.
func dawn() -> String:
	if phase != "night":
		end_day()
	_check_caught()
	var fresh := _night_strike()
	Cold.tick(self)
	var id := super.dawn()
	_ordinary_day()
	for a in _arrivals:
		today.append("New neighbour: %s" % a)
	_arrivals.clear()
	var lab_new: Array = CaseOps.lab_results(sim, _truth, det, int(sim.day))
	for e in lab_new:
		today.append("The lab reports: %s" % e["text"])
	if Serial.active(serial):
		var page: Dictionary = Serial.morning(serial, det, int(sim.day), fresh)
		if not page.is_empty():
			today.append("THE COURIER: %s" % page["head"])
			if serial["status"] == "failed":
				_aftermath("serial")
		if not fresh:
			var conf: Dictionary = Confessor.roll(sim, _truth, det, serial, court, seed_v, int(sim.day))
			if not conf.is_empty():
				today.append(Confessor.headline(sim, serial, String(conf["source"]), int(sim.day)))
				chronicle.append({"day": sim.day, "text": "%s confessed to the murders." % CaseEngine.name_of(sim, String(conf["source"]))})
		var kills: int = (serial["kills"] as Array).size()
		if fresh and kills == 2:
			pending_beats.append({"title": "THE PATTERN", "text": "A second body. A different house, a different family, nothing in common you can name. And on the table, the same thing: %s.\n\nOne is an accident of grief. Two is a hand. You do not say it aloud. Saying it aloud would make it a case about someone who is going to do it again." % String(serial["signature"]).to_lower()})
		elif fresh and kills == 3:
			pending_beats.append({"title": "THE THIRD", "text": "By noon the Courier knew. By dusk the whole town knew, and had given the killer a name: %s.\n\nYou have walked into %s now, and every one of them was somebody's ordinary life. There is a deadline, though nobody will say who set it. Eight days." % [String(serial["nick"]), _kill_places()]})
	_after_op()
	det.add_stress(-12.0 + (6.0 if Serial.active(serial) and float(serial["pressure"]) >= 70.0 else 0.0))
	return id


## If the killer you were hunting is now behind bars, the town learns of it.
func _check_caught() -> void:
	if Serial.active(serial) and solved() and (sim.people[serial["killer"]].jailed or sim.people[serial["killer"]].taken):
		var page: Dictionary = Serial.caught(serial, det, int(sim.day))
		if not page.is_empty():
			today.append("THE COURIER: %s" % page["head"])
			chronicle.append({"day": sim.day, "text": "%s was caught." % String(serial["nick"])})


func _kill_places() -> String:
	var ps: Array = []
	for k in (serial.get("kills", []) as Array).slice(-3):
		ps.append(String(k.get("place", "somewhere")))
	return Prose.list_join(ps)


## Quiet days: a front page, a piece of town business now and then.
func _ordinary_day() -> void:
	for b in business:
		if b["status"] == "open" and int(sim.day) > int(b["expires"]):
			b["status"] = "failed"
			Reputation.apply(det, "business_failed", int(sim.day))
	if _truth.get("status", "") in ["solved", "cold", "failed", "fled"] and not Serial.active(serial):
		var open_ids: Array = town_business().map(func(b): return b["id"])
		if open_ids.size() < 2:
			var b: Dictionary = Life.roll(sim, seed_v, int(sim.day), open_ids)
			if not b.is_empty():
				business.append(b)
				today.append("TOWN BUSINESS: %s. %s" % [b["title"], b["report"]])
	if not haunting.is_empty() and absi(hash("%d|haunt|%d" % [seed_v, int(sim.day)])) % 100 < 30:
		today.append("Someone has left a small thing on your step in the night: %s. No note." % String(haunting.get("signature", "a coin")).to_lower())
		det.add_stress(4.0)


## The night after the day just ended. Returns true when someone new has died.
func _night_strike() -> bool:
	var d := int(sim.day)
	if Serial.active(serial):
		if d < int(serial["next_strike"]):
			return false
		_open_case(Serial.opts(serial))
		Serial.record(sim, serial, _truth, seed_v, place_name(_truth["scene"]))
		return true
	if _truth.get("status", "") in ["solved", "cold", "failed", "fled"]:
		if not _truth.has("closed_day"):
			_truth["closed_day"] = d
		if not _truth.has("gap"):
			var gr := RandomNumberGenerator.new()
			gr.seed = hash("%d|gap|%d" % [seed_v, int(_truth["closed_day"])])
			_truth["gap"] = 2 + gr.randi() % 6          # a quiet stretch of two to seven days
		if d >= int(_truth["closed_day"]) + int(_truth["gap"]):
			var opt := {}
			var ss: String = String(serial.get("status", "none"))
			if not haunting.is_empty() and int(haunting.get("cases", 0)) >= 2:
				if ss == "failed":
					Serial.resume(serial, d)
				else:
					serial = Serial.adopt(sim, seed_v, String(haunting["killer"]), d, past_signatures)
					past_signatures.append(serial["signature"])
				haunting = {}
				opt = Serial.opts(serial)
			elif repeat_killer != "" and sim.alive(sim.people[repeat_killer]):
				opt = {"force_killer": repeat_killer, "avoid": [_truth.get("victim", "")]}
				repeat_killer = ""
			elif ss in ["none", "caught"] and haunting.is_empty() and Serial.rolls(seed_v, "d%d" % d):
				serial = Serial.begin(sim, seed_v, "d%d" % d, past_signatures)
				past_signatures.append(serial["signature"])
				opt = Serial.opts(serial)
			if not haunting.is_empty():
				haunting["cases"] = int(haunting["cases"]) + 1
			_welcome_newcomer()
			_open_case(opt)
			if Serial.active(serial):
				Serial.record(sim, serial, _truth, seed_v, place_name(_truth["scene"]))
			return true
	return false


## A new body, a new case file. A serial killer's earlier work stays in your notebook; an ordinary closed case does not.
func _open_case(opt: Dictionary) -> void:
	det.rollover(String(_truth.get("id", "old")))
	if opt.is_empty():
		det.known = {}
		det.order = []
	for k in beats_seen.keys():
		if not (k in ["pattern", "third"]):
			beats_seen.erase(k)
	if court.get("custody", "") != "":
		chronicle.append({"day": sim.day, "text": "%s was released: it happened again." % CaseEngine.name_of(sim, court["custody"])})
		court["custody"] = ""
	var c: Dictionary = CaseEngine.generate(sim, seed_v, int(sim.day), opt)
	CaseEngine.apply_backstory(sim, c)
	CaseEngine.execute(sim, c)
	c["claim_tags"] = (_truth.get("claim_tags", {}) as Dictionary).duplicate()      # the notebook keeps its old claims, and so does the court's memory of them
	c["claim_seq"] = int(_truth.get("claim_seq", 0))
	_truth = c
	_sync_case()


## 0-100, how loudly the town is shouting. 0 until a killer has taken three.
func pressure() -> float:
	return float(serial.get("pressure", 0.0))


func news() -> Array:
	return serial.get("news", [])


# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["det"] = det.to_dict()
	d["case"] = case.duplicate(true)          # the public case file
	d["truth"] = _truth.duplicate(true)       # the private truth, kept apart
	d["minutes"] = _minutes
	d["beats_seen"] = beats_seen.duplicate()
	d["pending_beats"] = pending_beats.duplicate(true)
	d["episodes"] = episodes.duplicate(true)
	d["court"] = court.duplicate(true)
	d["jail"] = jail.duplicate(true)
	d["mode"] = "detective"
	d["seed_v"] = seed_v
	d["serial"] = serial.duplicate(true)
	d["past_signatures"] = past_signatures.duplicate()
	d["newcomers"] = newcomers.duplicate(true)
	d["haunting"] = haunting.duplicate(true)
	d["repeat_killer"] = repeat_killer
	d["business"] = business.duplicate(true)
	d["town_news"] = town_news.duplicate(true)
	return d


func load_dict(d: Dictionary) -> void:
	newcomers = d.get("newcomers", []).duplicate(true)
	for n in newcomers:
		sim.register_resident(n)
	past_signatures = d.get("past_signatures", []).duplicate()
	super.load_dict(d)
	det = Detective.from_dict(d.get("det", {}))
	if d.has("truth"):
		_truth = d["truth"].duplicate(true)
	else:
		_truth = d.get("case", {}).duplicate(true)          # an older save kept everything in the one dictionary
	_sync_case()
	_minutes = int(d.get("minutes", 0))
	beats_seen = d.get("beats_seen", {}).duplicate()
	pending_beats = d.get("pending_beats", []).duplicate(true)
	episodes = d.get("episodes", []).duplicate(true)
	court = d.get("court", {"custody": ""}).duplicate(true)
	jail = d.get("jail", []).duplicate(true)
	seed_v = int(d.get("seed_v", 1961))
	serial = d.get("serial", Serial.none()).duplicate(true)
	haunting = d.get("haunting", {}).duplicate(true)
	repeat_killer = String(d.get("repeat_killer", ""))
	business = d.get("business", []).duplicate(true)
	town_news = d.get("town_news", []).duplicate(true)
	wishes = []


func save(path: String = DET_SAVE) -> bool:
	return super.save(path)


static func delete_save(path: String = DET_SAVE) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func has_detective_save(path: String = DET_SAVE) -> bool:
	return FileAccess.file_exists(path)


static func load_detective(path: String = DET_SAVE) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != SAVE_VERSION or d.get("mode", "") != "detective":
		return null
	var g: RefCounted = load("res://scripts/detective/detective_game.gd").new(int(d["seed"]), "", false, true)
	g.load_dict(d)
	return g
