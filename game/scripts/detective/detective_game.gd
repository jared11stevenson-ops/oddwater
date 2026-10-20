extends "res://scripts/sim/town_game.gd"
## The detective game: the town sim with you as its detective. A murder has already happened the night before the story starts;
## you wake on Day 1 at your own front door with the Sheriff's call. No swapping: you are always you.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")

const DET_SAVE := "user://detective_save.json"

var det: RefCounted
var case: Dictionary = {}
var _minutes := 0
var beats_seen: Dictionary = {}
var pending_beats: Array = []       # narrated interludes waiting to be shown
var episodes: Array = []            # the told stories of cases you have worked
var seed_v := 1961


func _init(seed_value: int = 1961, _first_host: String = "") -> void:
	super._init(seed_value, "player")
	seed_v = seed_value
	det = Detective.new()
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
	case = CaseEngine.generate(sim, seed_value, 0)
	CaseEngine.apply_backstory(sim, case)
	sim.simulate_rest_of_day()
	CaseEngine.execute(sim, case)
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


## Name the killer. The judge weighs your notebook; the town reacts.
func accuse(culprit: String, motive: String, method: String) -> Dictionary:
	var res: Dictionary = CaseOps.judge(sim, case, det, culprit, motive, method)
	CaseOps.apply_outcome(sim, case, det, res, culprit)
	var ep: Dictionary = Narrator.episode(sim, case, det, res)
	episodes.append(ep)
	res["episode"] = ep
	chronicle.append({"day": sim.day, "text": "You accused %s: %s." % [CaseEngine.name_of(sim, culprit), res["verdict"]]})
	return res


func suspects() -> Array:
	return case.get("suspects", [])


func solved() -> bool:
	return case.get("status", "") == "solved"


## Dawn: the lab reports in, and the town is the same town, one day on.
func dawn() -> String:
	var id := super.dawn()
	var lab_new: Array = CaseOps.lab_results(sim, case, det, int(sim.day))
	for e in lab_new:
		today.append("The lab reports: %s" % e["text"])
	_after_op()
	det.add_stress(-12.0)
	return id


# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["det"] = det.to_dict()
	d["case"] = case.duplicate(true)
	d["minutes"] = _minutes
	d["beats_seen"] = beats_seen.duplicate()
	d["pending_beats"] = pending_beats.duplicate(true)
	d["episodes"] = episodes.duplicate(true)
	d["mode"] = "detective"
	d["seed_v"] = seed_v
	return d


func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	det = Detective.from_dict(d.get("det", {}))
	case = d.get("case", {}).duplicate(true)
	_minutes = int(d.get("minutes", 0))
	beats_seen = d.get("beats_seen", {}).duplicate()
	pending_beats = d.get("pending_beats", []).duplicate(true)
	episodes = d.get("episodes", []).duplicate(true)
	seed_v = int(d.get("seed_v", 1961))
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
