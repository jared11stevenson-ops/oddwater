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
const Resources = preload("res://scripts/detective/resources.gd")
const Sheet = preload("res://scripts/detective/sheet.gd")
const Leads = preload("res://scripts/detective/leads.gd")
const Stakeout = preload("res://scripts/detective/stakeout.gd")
const Informants = preload("res://scripts/detective/informants.gd")
const Empathy = preload("res://scripts/detective/empathy.gd")
const Urgency = preload("res://scripts/detective/urgency.gd")
const Dread = preload("res://scripts/detective/dread.gd")

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
	Resources.ensure(det)
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
	Empathy.tick(self)
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
	if sim.hour_now() >= 21.0 and phase == "day":
		Dread.state(det)["late"] = int(sim.day)       # you kept dark hours; the night may notice
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


func ask(npc: String, topic: String, about: String = "", tone: String = "") -> Dictionary:
	var r: Dictionary = CaseOps.ask(sim, _truth, det, npc, topic, about, tone)
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


## Fast travel: walk to a place's door. The walk is paid in minutes (450 m per half hour, like every other trip) on the same clock as
## examining or questioning, so the town moves on by however many half hours it adds up to. `from_xy` is where you really stand (town
## metres); without it the trip starts from the building the sim has you at. Works at any hour of the day phase.
func travel_to(lot: String, from_xy: Vector2 = Vector2.INF) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "minutes": 0, "ticks": 0, "text": "It's too late to go anywhere. Sleep first."}
	var l: Dictionary = layout.by_id.get(lot, {})
	if l.is_empty():
		return {"ok": false, "minutes": 0, "ticks": 0, "text": "You don't know the way."}
	var d: float = distance(me().location, lot) if from_xy == Vector2.INF else from_xy.distance_to(Vector2(float(l["x"]), float(l["y"])))
	var mins: int = 0 if d < 12.0 else clampi(int(ceil(d / 15.0)), 2, 240)
	me().location = lot
	det.visit(lot)
	var ticks := 0
	if mins > 0:
		sim.player_activity = "errand"
		me().activity = "errand"
		spend(mins)
		ticks = flush_time()
	return {"ok": true, "minutes": mins, "ticks": ticks, "lot": lot, "text": "You walk to %s (%s)." % [place_name(lot), ("%d min" % mins) if mins > 0 else "right there"]}


## The surfaces at the scene worth dusting.
func dust_spots() -> Array:
	return ["door", "phone", "desk", "floor", "garden"]


func view_camera(cam_id: String, from_h: float, to_h: float) -> Dictionary:
	var r: Dictionary = Cctv.view(sim, _truth, det, cam_id, from_h, to_h, persons_of_interest())
	det.watched[_wkey(cam_id, from_h, to_h)] = true
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


## The tape of a stretch you have sat through, frame by frame (see Cctv.frames). Free to scrub, but only for a window you have watched.
const FRAME_STEP := 0.05

func camera_frames(cam_id: String, from_h: float, to_h: float, step: float = FRAME_STEP) -> Dictionary:
	if not det.watched.has(_wkey(cam_id, from_h, to_h)):
		return {"frames": [], "clock_checked": false, "radius": 0.0, "step": step, "locked": true}
	return Cctv.frames(sim, _truth, cam_id, from_h, to_h, step, det.calibrated.get(cam_id, false), persons_of_interest())


func _wkey(cam_id: String, a: float, b: float) -> String:
	return "%s|%d|%d" % [cam_id, int(a * 10), int(b * 10)]


## Tag a figure on the tape (by its track key at the camera-clock time `at`): a claim in the notebook, and a person of interest if the
## picture was good enough to name them. Returns {ok, text, who}.
func tag_figure(cam_id: String, from_h: float, to_h: float, at: float, key: String) -> Dictionary:
	var fr: Dictionary = camera_frames(cam_id, from_h, to_h)
	var cam: Dictionary = camera(cam_id)
	var best: Dictionary = {}
	var bd := 1e9
	for f in fr["frames"]:
		var d := absf(float(f["at"]) - at)
		if d > FRAME_STEP * 1.6 or d >= bd:
			continue
		for fg in f["figures"]:
			if fg["key"] == key:
				best = fg
				bd = d
	if best.is_empty() or cam.is_empty():
		return {"ok": false, "text": "Nobody there to tag.", "who": ""}
	var who: String = String(best["who"])
	var clock := Brief.clock_text(fposmod(at, 24.0))
	var eid := "tag_%s_%s_%d" % [cam_id, key, int(at * 20)]
	var nm: String = CaseEngine.name_of(sim, who) if who != "" else String(best["note"])
	var txt := "Tagged on %s at %s (camera clock): %s." % [cam["label"], clock, nm.capitalize() if who == "" else nm]
	var e := {"id": eid, "title": "Tagged: %s" % (nm if who != "" else "a figure"), "text": txt, "kind": "cctv", "source": cam["lot"], "day": int(sim.day), "camera": cam_id}
	var cert := 0.9 if who != "" else 0.5
	e["claims"] = Claims.emit(_truth, [Claims.make("recorded", who, "tagged_on_tape" if who != "" else "figure_seen", String(cam["lot"]), at, "" if who != "" else String(best["note"]).replace("a figure with ", ""), cert)], String(cam["lot"]), txt)
	var isnew: bool = det.learn(e)
	if who != "":
		flag_person(who)
	_after_op()
	return {"ok": true, "text": txt if isnew else "Already tagged.", "who": who, "new": isnew}


## Save the frame at `at` as a snapshot claim (what was on screen, by the camera's own clock).
func freeze_frame(cam_id: String, from_h: float, to_h: float, at: float) -> Dictionary:
	var fr: Dictionary = camera_frames(cam_id, from_h, to_h)
	if not fr["frames"].is_empty() and not Resources.has(det, "kit", 1):
		return {"ok": false, "text": "The kit is empty: no film left for the camera. It is restocked a little each morning."}
	var cam: Dictionary = camera(cam_id)
	if fr["frames"].is_empty() or cam.is_empty():
		return {"ok": false, "text": "No tape to freeze."}
	var best: Dictionary = fr["frames"][0]
	for f in fr["frames"]:
		if absf(float(f["at"]) - at) < absf(float(best["at"]) - at):
			best = f
	var n: int = (best["figures"] as Array).size()
	var named: Array = []
	for fg in best["figures"]:
		if fg["who"] != "":
			named.append(CaseEngine.name_of(sim, String(fg["who"])))
	var clock := Brief.clock_text(fposmod(float(best["at"]), 24.0))
	var txt := "Frozen frame, %s at %s (camera clock): %s%s." % [cam["label"], clock, "no one in view" if n == 0 else "%d figure%s in view" % [n, "" if n == 1 else "s"], (", including " + ", ".join(named)) if not named.is_empty() else ""]
	var e := {"id": "frame_%s_%d" % [cam_id, int(float(best["at"]) * 20)], "title": "Frame at %s" % clock, "text": txt, "kind": "cctv", "source": cam["lot"], "day": int(sim.day), "camera": cam_id}
	e["claims"] = Claims.emit(_truth, [Claims.make("recorded", "", "observation", String(cam["lot"]), float(best["at"]), "", 0.9 if det.calibrated.get(cam_id, false) else 0.7)], String(cam["lot"]), txt)
	var isnew: bool = det.learn(e)
	if isnew:
		Resources.spend(det, "kit", 1)
	_after_op()
	return {"ok": true, "text": txt if isnew else "You already saved that frame.", "new": isnew}


## The evidence board's cards: one per claim in the notebook (newest `limit`), by channel and place/time, from the notebook alone.
func board_cards(limit: int = 12) -> Array:
	var out: Array = []
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		var kind := String(e.get("kind", ""))
		if kind in ["lore", "scandal"] or String(eid).begins_with("cmp_"):
			continue
		var ch := "records"
		match kind:
			"testimony", "confession": ch = "testimony"
			"physical", "print", "found", "watch": ch = "physical"
			"lab": ch = "lab"
		for cl in e.get("claims", []):
			var t: float = float(cl.get("time", -1.0))
			var place := String(cl.get("place", "")) if String(cl.get("place", "")) != "" else String(e.get("source", ""))
			var pl: String = place_name(place) if layout.by_id.has(place) else ""
			var pred := String(cl.get("predicate", "")).replace("_", " ")
			out.append({"cid": String(cl.get("cid", "")), "eid": String(eid), "title": String(e.get("title", "")), "sub": pred if pred != "observation" else "noted",
				"text": String(e.get("text", "")), "channel": ch, "group": pl if pl != "" else "Elsewhere", "time": t, "subject": String(cl.get("subject", ""))})
	if out.size() > limit:
		out = out.slice(out.size() - limit)
	out.sort_custom(func(a, b): return a["group"] < b["group"] or (a["group"] == b["group"] and float(a["time"]) < float(b["time"])))
	return out


## Contradictions the rules of evidence find in the notebook (never the truth): [{a, b, who, why}] by entry id.
func board_contradictions() -> Array:
	return Reasoning.contradictions(det.known, case)


## String a claim to a person (or cut the string). Returns true if the string now stands.
func board_theory(claim: String, person: String) -> bool:
	return det.set_theory(claim, person)


func board_read(person: String) -> String:
	return det.board_read(person, CaseEngine.first(sim, person) if sim.people.has(person) else "")


func calibrate_camera(cam_id: String) -> Dictionary:
	var r: Dictionary = Cctv.calibrate(sim, _truth, det, cam_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func dust(lot: String, spot: String, effort: float = -1.0) -> Dictionary:
	var key := "%s|%s" % [lot, spot]
	Resources.ensure(det)
	var fresh: bool = lot == String(_truth["scene"]) and not (det.res["dusted"] as Dictionary).has(key)
	if fresh and not Resources.spend(det, "kit", 1):
		return {"text": "The kit is empty: no powder, no lifting tape. It is restocked a little each morning.", "learned": [], "minutes": 0, "ticks": 0, "blocked": "kit"}
	if fresh:
		det.res["dusted"][key] = true
	var r: Dictionary = Prints.dust(sim, _truth, det, lot, spot, effort)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func take_sample(npc: String) -> Dictionary:
	var had: bool = bool(det.samples.get(npc, false))
	if not had and not Resources.has(det, "kit", 1):
		return {"ok": false, "text": "The kit is empty: no ink, no cards. It is restocked a little each morning.", "minutes": 0, "ticks": 0, "blocked": "kit"}
	var r: Dictionary = Prints.take_sample(sim, _truth, det, npc)
	if not had and bool(det.samples.get(npc, false)):
		Resources.spend(det, "kit", 1)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func compare_print(print_entry: String, target: String) -> Dictionary:
	var r: Dictionary = Prints.submit_compare(sim, _truth, det, print_entry, target)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


## `rush`: call in a favour when the day's lab slots are gone (the technician stays late).
func submit_lab(clue_id: String, rush: bool = false) -> Dictionary:
	var day := int(sim.day)
	var already: bool = det.lab.any(func(l): return String(l.get("clue", "")) == clue_id) or det.lab_done.has(clue_id)
	var via_favour := false
	if not already and det.has(clue_id) and Resources.lab_free(det, day) <= 0:
		if rush and Resources.spend(det, "favours", 1):
			via_favour = true
		else:
			return {"text": "The lab has its %d jobs for today and no more. Tomorrow, or call in a favour and the technician will stay late." % Resources.lab_slots(det), "minutes": 0, "ticks": 0, "blocked": "lab"}
	var r: Dictionary = CaseOps.submit_to_lab(sim, _truth, det, clue_id)
	if not already and det.lab.any(func(l): return String(l.get("clue", "")) == clue_id):
		if not via_favour:
			Resources.use_lab(det, day)
		else:
			r["text"] = String(r["text"]) + " (A favour spent: the technician stays late.)"
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func warrant(target: String) -> Dictionary:
	if not det.warrants.get(target, false) and not Resources.has(det, "warrants", 1):
		return {"ok": false, "text": "Judge Moss shakes their head. \"You have used the warrants I can justify on this file. Bring me something I can't ignore, and wait.\"", "minutes": 0, "ticks": 0, "blocked": "warrants"}
	var had: bool = bool(det.warrants.get(target, false))
	var r: Dictionary = CaseOps.request_warrant(sim, _truth, det, target)
	if not had and bool(det.warrants.get(target, false)):
		Resources.spend(det, "warrants", 1)
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
## `charge` is the rung of the charge ladder the case sheet allows (see Sheet.charge_level): "" and "murder" run the whole road at once; "killing"
## and "held" lay a smaller charge, hold the accused and set the trial three days on, with a shorter sentence if it ends in a conviction.
func accuse(culprit: String, motive: String, method: String, charge: String = "") -> Dictionary:
	var lesser: bool = charge in ["killing", "held"]
	if not can_accuse():
		return {"verdict": "barred", "text": "The Sheriff will not hear another accusation on this file.", "score": 0, "cats": 0, "total": 0, "left": 0}
	if not sim.people.has(culprit) or culprit == "player" or not sim.alive(sim.people[culprit]) or culprit == String(_truth["victim"]):
		return {"verdict": "barred", "text": "There is no one in Little Mercy by that name to accuse.", "score": 0, "cats": 0, "total": 0, "left": accusations_left()}
	var res: Dictionary = CaseOps.judge(sim, _truth, det, culprit, motive, method)
	if lesser:
		court["sentence_cap"] = int(Sheet.SENTENCE[charge])
	_truth["accusations"] = int(_truth.get("accusations", 0)) + 1
	(_truth["accused"] as Array).append(culprit)
	var theory: bool = res["right_motive"] and res["right_method"]
	match String(res["verdict"]):
		"convicted":
			if lesser:
				var lc: Dictionary = Justice.formal_charge(sim, _truth, det, court, jail, culprit, false, false)
				res["interview"] = lc["interview"]
				res["verdict"] = "charged"
				res["text"] = Prose.clean("%s is charged with %s, and held. The trial is set for day %d. You have until then to prove the rest." % [CaseEngine.name_of(sim, culprit), String(Sheet.CHARGES[charge]).to_lower(), int(court.get("trial_day", 0))])
				det.gain_xp(40)
			else:
				var ch: Dictionary = Justice.formal_charge(sim, _truth, det, court, jail, culprit, theory, true)
				var tr: Dictionary = ch["trial"]
				res["trial"] = tr
				res["interview"] = ch["interview"]
				if charge == "murder" and tr["verdict"] == "guilty":
					det.gain_xp(40)
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
	if _truth.get("status", "") == "open" and accusations_left() == 0 and not (res["verdict"] in ["released", "charged"]):
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


# ------------------------------------------------------------------ the case sheet (fill in the case)
func sheet() -> Dictionary:
	return Sheet.ensure(det)


## What each group's stamp says on the page. The text never says which part is wrong.
func sheet_lines() -> Dictionary:
	var d: Dictionary = Prose.json("detective/sheet.json")
	var sh: Dictionary = sheet()
	var out := {}
	for g in Sheet.GROUPS:
		var gid: String = g["id"]
		var st: String = String(sh["stamps"].get(gid, "open"))
		var bank: Array = d["open"] if st == "open" else d["confirmed" if st == "confirmed" else "unsupported"][gid]
		var line: String = String(bank[absi(hash("%s|%s|%s|%d" % [case.get("id", ""), gid, st, int(sh.get("checks", 0))])) % bank.size()])
		if gid == "reason" and st == "unsupported" and Sheet.pattern(det) and String(sh["stamps"].get("night", "")) == "confirmed" and String(sh["stamps"].get("act", "")) == "confirmed":
			line = String(d["pattern"][absi(hash("%s|pat" % case.get("id", ""))) % d["pattern"].size()])
		out[gid] = {"stamp": st, "text": line}
	return out


## Set one line of the sheet ("" clears it). Changing an answer takes the stamp off every group it belongs to.
func sheet_set(field: String, value: String) -> void:
	var sh: Dictionary = sheet()
	if not (field in Sheet.FIELDS):
		return
	if String(sh[field]) != value:
		sh[field] = value
		_sheet_dirty(field)
		if field == "who" and value != "" and sim.people.has(value):
			flag_person(value)


func _sheet_dirty(field: String) -> void:
	var sh: Dictionary = sheet()
	for g in Sheet.GROUPS:
		if field in g["fields"] or field == "cites":
			sh["stamps"][g["id"]] = "open"


## Cite (or stop citing) a notebook claim as support for one line.
func sheet_cite(field: String, cid: String, on: bool) -> void:
	var sh: Dictionary = sheet()
	if not (field in Sheet.FIELDS):
		return
	var arr: Array = sh["cites"][field]
	if on and not arr.has(cid) and Sheet.index(det).has(cid):
		arr.append(cid)
	elif not on:
		arr.erase(cid)
	for g in Sheet.GROUPS:
		if field in g["fields"] or field == "who":
			sh["stamps"][g["id"]] = "open"


## The claims in the notebook a line could cite, as cards (the newest first), with whether each is cited under that line.
func sheet_cards(field: String) -> Array:
	var sh: Dictionary = sheet()
	var cites: Array = sh["cites"].get(field, [])
	var out: Array = []
	var seen := {}
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		if String(e.get("kind", "")) in ["lore", "scandal"]:
			continue
		for cl in e.get("claims", []):
			var cid := String(cl.get("cid", ""))
			if cid == "" or seen.has(cid) or String(cl.get("predicate", "")) in ["observation", "legacy"]:
				continue
			seen[cid] = true
			var t: float = float(cl.get("time", -1.0))
			var subj := String(cl.get("subject", ""))
			out.append({"cid": cid, "eid": String(eid), "title": String(e.get("title", "")), "text": String(e.get("text", "")), "pred": String(cl.get("predicate", "")).replace("_", " "), "predicate": String(cl.get("predicate", "")),
				"subject": subj, "who": CaseEngine.first(sim, subj) if subj != "" and sim.people.has(subj) else "", "time": t, "cited": cites.has(cid),
				"clock": Brief.clock_text(fposmod(t, 24.0)) if t >= 0.0 else "", "place": place_name(String(cl.get("place", ""))) if layout.by_id.has(String(cl.get("place", ""))) else ""})
	out.reverse()
	return out


## Press CHECK: the stamps. Costs time, more for the third and later check in a day (a detective who guesses at the sheet is told so by the clock).
func sheet_check() -> Dictionary:
	var sh: Dictionary = sheet()
	var day := int(sim.day)
	var key := "checks_day"
	if int(sh.get(key + "_d", -1)) != day:
		sh[key + "_d"] = day
		sh[key] = 0
	sh[key] = int(sh[key]) + 1
	var n: int = int(sh[key])
	var mins: int = 30 * maxi(1, n - 1)
	if n >= 3:
		det.add_stress(2.0)
	sh["checks"] = int(sh.get("checks", 0)) + 1
	sh["stamps"] = Sheet.adjudicate(det, case, det.ctx.get("jobs", {}), sh, _truth)
	var r := {"stamps": sh["stamps"].duplicate(), "lines": sheet_lines(), "level": Sheet.charge_level(sh["stamps"], Sheet.pattern(det)), "minutes": mins}
	r["ticks"] = spend(mins)
	_after_op()
	return r


func sheet_level() -> String:
	var sh: Dictionary = sheet()
	for gid in sh["stamps"]:
		if sh["stamps"][gid] == "open" and Sheet.group_complete(sh, gid):
			return "unchecked"
	return Sheet.charge_level(sh["stamps"], Sheet.pattern(det))


## Test theory: the timeline and links against the recorded observations. Returns only the contradictions found in the notebook.
func sheet_test_theory() -> Dictionary:
	var sh: Dictionary = sheet()
	var d: Dictionary = Prose.json("detective/sheet.json")
	var r: Dictionary = Sheet.test_theory(sim, det, case, det.ctx.get("jobs", {}), sh, layout.by_id, func(id: String) -> String: return CaseEngine.name_of(sim, id))
	var lead_in: String = String(d["theory_open"][absi(hash("%s|th|%d" % [case.get("id", ""), det.order.size()])) % d["theory_open"].size()])
	var lines: Array = r["lines"]
	var text := ""
	if lines.is_empty() or (lines.size() == 1 and String(lines[0]).begins_with("There is no name")):
		text = String(d["theory_none"][absi(hash("%s|tn|%d" % [case.get("id", ""), det.order.size()])) % d["theory_none"].size()]) if sh["who"] != "" else String(lines[0])
	else:
		text = lead_in + "\n- " + "\n- ".join(lines)
	var out := {"lines": lines, "count": int(r["count"]), "text": Prose.clean(text), "minutes": 45}
	out["ticks"] = spend(45)
	det.add_stress(1.0)
	_after_op()
	return out


## A hunch: one point of gut for a LEAD. Never a verdict; may be incomplete, may be an hour out.
func sheet_hunch() -> Dictionary:
	if not Resources.has(det, "hunches", 1):
		return {"ok": false, "text": String(Prose.json("detective/sheet.json")["hunch_out"]), "minutes": 0}
	Resources.spend(det, "hunches", 1)
	var lead: Dictionary = Leads.lead(self, int(det.dread.get("hunches_used", 0)))
	det.dread["hunches_used"] = int(det.dread.get("hunches_used", 0)) + 1
	var r := {"ok": true, "text": String(lead["text"]), "kind": String(lead["kind"]), "minutes": 15}
	r["ticks"] = spend(15)
	return r


## File the sheet. The charge is what the stamps allow. With nothing confirmed you may still press a charge on your own judgement, if the
## notebook gives probable cause, and answer for it if it fails (the same road as ever).
func sheet_file(force: bool = false) -> Dictionary:
	var sh: Dictionary = sheet()
	var d: Dictionary = Prose.json("detective/sheet.json")
	if String(sh["who"]) == "":
		return {"verdict": "blank", "text": "There is no name on the sheet."}
	var lv: String = sheet_level()
	if lv == "unchecked":
		return {"verdict": "unchecked", "text": "Press CHECK first: the stamps are not current."}
	var text := ""
	if lv == "unconfirmed":
		if not force:
			return {"verdict": "unconfirmed", "text": String(d["charge"]["unconfirmed"][0])}
		if not Justice.probable_cause(det, String(sh["who"])):
			return {"verdict": "no_cause", "text": String(d["no_cause"])}
	var r: Dictionary = accuse(String(sh["who"]), String(sh["why"]), String(sh["how"]), "" if lv == "unconfirmed" else lv)
	r["level"] = lv
	if lv != "unconfirmed":
		text = String(d["charge"][lv][absi(hash("%s|ch" % case.get("id", ""))) % d["charge"][lv].size()])
		r["text"] = text + "\n\n" + String(r.get("text", ""))
	sh["stamps"] = {"night": "open", "act": "open", "reason": "open"}
	return r


# ------------------------------------------------------------------ stakeouts, informants, deals
func stakeout(lot: String, hours: int) -> Dictionary:
	var r: Dictionary = Stakeout.run(self, lot, hours)
	if bool(r.get("spotted", false)):
		Reputation.apply(det, "spotted_watching", int(sim.day))
	_after_op()
	return r


func stakeout_hours() -> int:
	return Stakeout.hours_available(self)


func street_contacts() -> Array:
	return Informants.contacts(self)


func informant_tip(contact: String) -> Dictionary:
	var r: Dictionary = Informants.tip(self, contact)
	r["ticks"] = spend(int(r.get("minutes", 0)))
	_after_op()
	return r


## A plea for the person in custody: a reduced sentence for a statement. Wrong, and an innocent is in a cell while the killer walks.
func plea_deal(target: String) -> Dictionary:
	var r: Dictionary = Informants.deal(self, target)
	if not bool(r.get("accepted", false)):
		r["ticks"] = spend(30 if bool(r.get("ok", false)) else 0)
		_after_op()
		return r
	var res: Dictionary = r["res"]
	Justice.conclude(sim, _truth, det, court, jail, res)
	if bool(res.get("wrongful", false)):
		_truth["false_conviction"] = target
		Reputation.apply(det, "wrong_plea", int(sim.day))
	var ep: Dictionary = Narrator.episode(sim, _truth, det, {"verdict": "convicted" if not bool(res.get("wrongful", false)) else "wrong", "score": 0, "right_person": not bool(res.get("wrongful", false))})
	episodes.append(ep)
	chronicle.append({"day": sim.day, "text": "%s took a plea." % CaseEngine.name_of(sim, target)})
	_false_conviction_check()
	_check_caught()
	r["ticks"] = spend(45)
	_sync_case()
	return r


# ------------------------------------------------------------------ empathy
func dossier() -> Dictionary:
	return Empathy.dossier(self)


func remember_them(npc: String) -> Dictionary:
	var r: Dictionary = Empathy.remember(self, npc)
	r["ticks"] = spend(int(r.get("minutes", 0)))
	_after_op()
	return r


func can_tell(npc: String) -> bool:
	return Empathy.can_tell(self, npc)


func tell_family(npc: String, approach: String) -> Dictionary:
	var r: Dictionary = Empathy.tell(self, npc, approach)
	r["ticks"] = spend(int(r.get("minutes", 0)))
	_after_op()
	return r


func family_circle() -> Array:
	return Empathy.circle(self).map(func(x): return {"id": x["id"], "rel": x["rel"]})


func carrying() -> String:
	return Empathy.carrying(self)


func can_return_keepsake() -> bool:
	return Empathy.can_return(self)


func return_keepsake() -> Dictionary:
	var r: Dictionary = Empathy.return_keepsake(self)
	r["ticks"] = spend(int(r.get("minutes", 0)))
	_after_op()
	return r


# ------------------------------------------------------------------ urgency and dread
func trails() -> Array:
	return Urgency.trails(self)


func resource_line() -> String:
	return Resources.summary(det, int(sim.day))


func resource_rows() -> Array:
	return Resources.rows(det, int(sim.day))


func dread_level() -> int:
	return Dread.level(det, sim.hour_now())


func dread_name() -> String:
	return Dread.level_name(dread_level())


func dread_whisper() -> String:
	return Dread.whisper(self)


func dread_intrusion() -> Dictionary:
	return Dread.intrusion(self)


func dread_take(idea: String, who: String) -> Dictionary:
	var r: Dictionary = Dread.accept(self, idea, who)
	_after_op()
	return r


func dread_dismiss() -> String:
	return Dread.dismiss(self)


func dread_pending() -> Dictionary:
	return Dread.pending(det)


func dread_respond(choice: String) -> Dictionary:
	var r: Dictionary = Dread.respond(self, choice)
	_after_op()
	return r


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
	text += "\n\n" + Empathy.eulogy(self)
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
	Resources.dawn(det, int(sim.day))
	Dread.dawn(self)
	Dread.reply_due(self)
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
	for ln in Urgency.morning(self):
		today.append(ln)
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
	Resources.new_case(det, int(sim.day))
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
	Resources.ensure(det)
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
