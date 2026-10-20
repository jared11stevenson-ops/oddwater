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

const DET_SAVE := "user://detective_save.json"

var det: RefCounted
var case: Dictionary = {}
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


## The town grows: two days after a case is fully solved, someone new moves in.
func _welcome_newcomer() -> void:
	var d: Dictionary = sim.make_newcomer(newcomers.size() + 1)
	newcomers.append(d)
	_arrivals.append("%s, %d, a %s, has moved into %s." % [d["name"], int(d["age"]), String(d["job"]), place_name(d["home"])])
	chronicle.append({"day": sim.day, "text": "%s moved to Little Mercy." % d["name"]})


## `force_serial` makes the first murder the work of a serial killer (tests; a rare thing in real play).
func _init(seed_value: int = 1961, _first_host: String = "", force_serial: bool = false) -> void:
	super._init(seed_value, "player")
	seed_v = seed_value
	_force_serial = force_serial
	det = Detective.new()
	serial = Serial.none()
	sim.release_control()
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
	case = CaseEngine.generate(sim, seed_value, 0, opt)
	CaseEngine.apply_backstory(sim, case)
	sim.simulate_rest_of_day()
	CaseEngine.execute(sim, case)
	if Serial.active(serial):
		Serial.record(sim, serial, case, seed_value, place_name(case["scene"]))
	sim.slack()
	sim.start_day()
	_seen_events = 0


func briefing() -> String:
	return CaseEngine.discovery_text(sim, case)


func opening() -> String:
	return Narrator.cold_open(sim, case)


## After anything you do: has the story reached a moment worth telling?
func _after_op() -> void:
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
	if solved():
		return "Case closed. Rest, and watch the town."
	var v: String = case.get("victim", "")
	if not det.has("c_body"):
		return "Examine the crime scene: %s." % place_name(scene_lot())
	var asked := {}
	for st in det.statements:
		asked[st["npc"]] = true
	if not asked.has(case.get("found_by", "")):
		return "Question %s, who found the body." % CaseEngine.name_of(sim, case["found_by"])
	var unasked: Array = suspects().filter(func(s): return not asked.has(s))
	if not unasked.is_empty():
		return "Interview the suspects. Next: %s." % CaseEngine.name_of(sim, unasked[0])
	if det.has("c_dropped") and not det.has("lab_c_dropped") and det.lab.is_empty():
		return "Send %s to the lab." % String(case["item"])
	if det.known.size() < 8:
		return "Canvass the neighbours of the scene and of each suspect."
	return "Look for what contradicts what you have been told. Then decide."


func spots(lot: String) -> Array:
	return CaseOps.spots_at(sim, case, lot)


func examine(lot: String, spot: String) -> Dictionary:
	var r: Dictionary = CaseOps.examine(sim, case, det, lot, spot)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func ask(npc: String, topic: String, about: String = "") -> Dictionary:
	var r: Dictionary = CaseOps.ask(sim, case, det, npc, topic, about)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func present(npc: String, entry_id: String) -> Dictionary:
	var r: Dictionary = CaseOps.present(sim, case, det, npc, entry_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func cameras() -> Array:
	return Cctv.cameras(case)


func view_camera(cam_id: String, from_h: float, to_h: float) -> Dictionary:
	var r: Dictionary = Cctv.view(sim, case, det, cam_id, from_h, to_h)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func calibrate_camera(cam_id: String) -> Dictionary:
	var r: Dictionary = Cctv.calibrate(sim, case, det, cam_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func dust(lot: String, spot: String) -> Dictionary:
	var r: Dictionary = Prints.dust(sim, case, det, lot, spot)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func take_sample(npc: String) -> Dictionary:
	var r: Dictionary = Prints.take_sample(sim, case, det, npc)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func compare_print(print_entry: String, target: String) -> Dictionary:
	var r: Dictionary = Prints.submit_compare(sim, case, det, print_entry, target)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func submit_lab(clue_id: String) -> Dictionary:
	var r: Dictionary = CaseOps.submit_to_lab(sim, case, det, clue_id)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func warrant(target: String) -> Dictionary:
	var r: Dictionary = CaseOps.request_warrant(sim, case, det, target)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func arrest(target: String) -> Dictionary:
	var r: Dictionary = Justice.arrest(sim, case, det, court, target)
	_after_op()
	return r


func interrogate(approach: String) -> Dictionary:
	var r: Dictionary = Justice.interrogate(sim, case, det, court, approach)
	r["ticks"] = spend(int(r["minutes"]))
	_after_op()
	return r


func trial_ready() -> bool:
	return court.get("custody", "") != "" and sim.day >= int(court.get("trial_day", 999))


## The trial: the defence attacks, the jury decides, and the verdict is applied to the town.
func run_trial() -> Dictionary:
	var t: String = court.get("custody", "")
	if t == "":
		return {"verdict": "none", "attacks": [], "confidence": 0}
	var res: Dictionary = Justice.trial(sim, case, det, t)
	Justice.conclude(sim, case, det, court, jail, res)
	var ep: Dictionary = Narrator.episode(sim, case, det, {"verdict": "convicted" if res["verdict"] == "guilty" and not res["wrongful"] else "wrong" if res["verdict"] == "guilty" else "released", "score": int(res["confidence"]), "right_person": t == case["killer"]})
	if res["verdict"] in ["guilty", "not guilty"]:
		episodes.append(ep)
		res["episode"] = ep
	chronicle.append({"day": sim.day, "text": "Trial of %s: %s." % [CaseEngine.name_of(sim, t), res["verdict"]]})
	_check_caught()
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
	var r: Dictionary = Justice.visit(sim, case, det, i, topic)
	r["ticks"] = spend(int(r["minutes"]))
	return r


func appeal(id: String) -> Dictionary:
	var i: Dictionary = inmate(id)
	if i.is_empty():
		return {"ok": false, "text": "They are not here."}
	return Justice.appeal(sim, case, det, jail, i)


## Name the killer. The judge weighs your notebook; the town reacts.
func accuse(culprit: String, motive: String, method: String) -> Dictionary:
	var res: Dictionary = CaseOps.judge(sim, case, det, culprit, motive, method)
	CaseOps.apply_outcome(sim, case, det, res, culprit)
	var ep: Dictionary = Narrator.episode(sim, case, det, res)
	episodes.append(ep)
	res["episode"] = ep
	chronicle.append({"day": sim.day, "text": "You accused %s: %s." % [CaseEngine.name_of(sim, culprit), res["verdict"]]})
	_check_caught()
	return res


func suspects() -> Array:
	return case.get("suspects", [])


func solved() -> bool:
	return case.get("status", "") == "solved"


## Dawn: the night's work is done (a killer may have struck), the lab reports in, and the town is the same town, one day on.
func dawn() -> String:
	if phase != "night":
		end_day()
	_check_caught()
	var fresh := _night_strike()
	var id := super.dawn()
	for a in _arrivals:
		today.append("New neighbour: %s" % a)
	_arrivals.clear()
	var lab_new: Array = CaseOps.lab_results(sim, case, det, int(sim.day))
	for e in lab_new:
		today.append("The lab reports: %s" % e["text"])
	if Serial.active(serial):
		var page: Dictionary = Serial.morning(serial, det, int(sim.day), fresh)
		if not page.is_empty():
			today.append("THE COURIER: %s" % page["head"])
			if serial["status"] == "failed":
				chronicle.append({"day": sim.day, "text": "The state police took the serial case from you."})
		var kills: int = (serial["kills"] as Array).size()
		if fresh and kills == 2:
			pending_beats.append({"title": "THE PATTERN", "text": "A second body. A different house, a different family, nothing in common you can name. And on the table, the same thing: %s.\n\nOne is an accident of grief. Two is a hand. You do not say it aloud. Saying it aloud would make it a case about someone who is going to do it again." % String(serial["signature"]).to_lower()})
		elif fresh and kills == 3:
			pending_beats.append({"title": "THE THIRD", "text": "By noon the Courier knew. By dusk the whole town knew, and had given the killer a name: %s.\n\nYou have walked into three kitchens now and every one of them smelled of toast. There is a deadline, though nobody will say who set it. Eight days." % String(serial["nick"])})
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


## The night after the day just ended. Returns true when someone new has died.
func _night_strike() -> bool:
	var d := int(sim.day)
	if Serial.active(serial):
		if d < int(serial["next_strike"]):
			return false
		_open_case(Serial.opts(serial))
		Serial.record(sim, serial, case, seed_v, place_name(case["scene"]))
		return true
	if case.get("status", "") == "solved":
		if not case.has("closed_day"):
			case["closed_day"] = d
		elif d >= int(case["closed_day"]) + 2 and serial.get("status", "none") != "failed":
			var opt := {}
			if Serial.rolls(seed_v, "d%d" % d):
				serial = Serial.begin(sim, seed_v, "d%d" % d, past_signatures)
				past_signatures.append(serial["signature"])
				opt = Serial.opts(serial)
			_welcome_newcomer()
			_open_case(opt)
			if Serial.active(serial):
				Serial.record(sim, serial, case, seed_v, place_name(case["scene"]))
			return true
	return false


## A new body, a new case file. A serial killer's earlier work stays in your notebook; an ordinary closed case does not.
func _open_case(opt: Dictionary) -> void:
	det.rollover(String(case.get("id", "old")))
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
	case = c


## 0-100, how loudly the town is shouting. 0 until a killer has taken three.
func pressure() -> float:
	return float(serial.get("pressure", 0.0))


func news() -> Array:
	return serial.get("news", [])


# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["det"] = det.to_dict()
	d["case"] = case.duplicate(true)
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
	return d


func load_dict(d: Dictionary) -> void:
	newcomers = d.get("newcomers", []).duplicate(true)
	for n in newcomers:
		sim.register_resident(n)
	past_signatures = d.get("past_signatures", []).duplicate()
	super.load_dict(d)
	det = Detective.from_dict(d.get("det", {}))
	case = d.get("case", {}).duplicate(true)
	_minutes = int(d.get("minutes", 0))
	beats_seen = d.get("beats_seen", {}).duplicate()
	pending_beats = d.get("pending_beats", []).duplicate(true)
	episodes = d.get("episodes", []).duplicate(true)
	court = d.get("court", {"custody": ""}).duplicate(true)
	jail = d.get("jail", []).duplicate(true)
	seed_v = int(d.get("seed_v", 1961))
	serial = d.get("serial", Serial.none()).duplicate(true)
	wishes = []


func save(path: String = DET_SAVE) -> bool:
	return super.save(path)


static func has_detective_save(path: String = DET_SAVE) -> bool:
	return FileAccess.file_exists(path)


static func load_detective(path: String = DET_SAVE) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != SAVE_VERSION or d.get("mode", "") != "detective":
		return null
	var g: RefCounted = load("res://scripts/detective/detective_game.gd").new(int(d["seed"]))
	g.load_dict(d)
	return g
