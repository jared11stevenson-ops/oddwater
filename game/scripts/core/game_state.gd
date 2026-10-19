extends RefCounted
## The whole run: day, phase, Notes, Remnants, Case Board, suspicion, town mood.

const Data = preload("res://scripts/core/data.gd")
const Notes = preload("res://scripts/core/notes.gd")
const CaseBoard = preload("res://scripts/core/case_board.gd")
const Suspicion = preload("res://scripts/core/suspicion.gd")
const Remnants = preload("res://scripts/core/remnants.gd")

enum Phase { WAKE, PERFORM, STEP_OFF, NIGHT, SLACK, ENDED }

var tuning: Dictionary
var lives: Array
var endings: Dictionary
var day := 1
var phase: Phase = Phase.WAKE
var notes: RefCounted
var board: RefCounted
var suspicion: RefCounted
var remnants: RefCounted
var town_mood := 60
var ending := ""
var flags: Dictionary = {}   # story flags: hymn_aired, delphine_resigned ...
var claims: Dictionary = {}     # claim id -> "heard" | "cracked"
var drift := 0.0               # the Hush winning: comfort. Hidden from the player as a friendly label
var contentment := 0.0
var alignment := 0.0           # played the person the way the clues say they were
var notoriety := 0.0           # ruined or remade lives; the town talks
var dawn_seals := 0
var dawn_cracks := 0
var dawn_photos := 0
var host_history: Array = []   # who the player has been, day by day (day N is host_history[N-1])
var next_host := ""          # set at the Slack by the Cause; blank = authored order
var honesty_pull := 0   # a child's fibs build up; at 100 the truth blurts out (resets each day)


func _init() -> void:
	tuning = Data.load_json("tuning.json")
	lives = Data.load_json("lives.json")
	endings = Data.load_json("endings.json")
	host_history = [lives[0]["id"]]
	board = CaseBoard.new()
	suspicion = Suspicion.new(tuning)
	remnants = Remnants.new(tuning)
	notes = Notes.new()
	_enter_day()


func life_by_id(id: String) -> Dictionary:
	for l in lives:
		if l["id"] == id:
			return l
	return lives[lives.size() - 1]


func current_life() -> Dictionary:
	if day <= host_history.size():
		return life_by_id(host_history[day - 1])
	return lives[mini(day, lives.size()) - 1]


## The authored order: the first life not yet hosted, or the Prop Room when they are all used.
func baseline_next_id() -> String:
	for l in lives:
		if l["id"] != "prop_room" and not host_history.has(l["id"]):
			return l["id"]
	return "prop_room"


func is_foggy() -> bool:
	return town_mood < int(tuning["fog_below_mood"])


## Hush strength 0..1: strong when the town is calm.
func hush_strength() -> float:
	return clampf(town_mood / 100.0, 0.0, 1.0)


func cracked_count() -> int:
	var n := 0
	for k in claims:
		if claims[k] == "cracked":
			n += 1
	return n


func _enter_day() -> void:
	notes = Notes.new()
	honesty_pull = 0
	dawn_seals = board.seals.size()
	dawn_cracks = cracked_count()
	dawn_photos = board.notebook.size()
	var tool_id: String = current_life()["proof_tool"]
	for l in lives:
		board.set_tool(l["proof_tool"], false)
	board.set_tool(tool_id, true)
	# Overlap: Remnants who like you run their old Proof Tool for you.
	for l in lives:
		if l["id"] != current_life()["id"] and remnants.willing(l["id"]):
			board.set_tool(l["proof_tool"], true)
	if board.has_ability("overlay"):
		board.set_tool("map", true)
	board.set_tool("board", day >= 14)
	board.set_tool("roll", day >= 14)


## Move to the next beat. Returns the new phase.
func advance(keep_note: String = "") -> Phase:
	match phase:
		Phase.WAKE:
			phase = Phase.PERFORM
		Phase.PERFORM:
			phase = Phase.STEP_OFF
		Phase.STEP_OFF:
			var keep := keep_note if board.has_ability("shed") else ""
			remnants.step_off(current_life()["id"], day, notes, keep)
			phase = Phase.NIGHT
		Phase.NIGHT:
			phase = Phase.SLACK
		Phase.SLACK:
			suspicion.decay_overnight(is_foggy())
			if day >= int(tuning["last_day"]):
				ending = ending_for()
				phase = Phase.ENDED
			else:
				var nh := next_host if next_host != "" else baseline_next_id()
				host_history.append(nh)
				next_host = ""
				day += 1
				phase = Phase.WAKE
				_enter_day()
	return phase


## Vern's choice. Airing Hymn #212 wakes the walk-ons: the town gets afraid (fog), the Waking grows.
func apply_hymn(aired: bool) -> void:
	flags["hymn_aired"] = aired
	flags["hymn_decided"] = true
	if aired:
		town_mood = clampi(town_mood - 25, 0, 100)
		for npc in ["silas", "bea", "dolores", "fitz", "roy", "connie"]:
			suspicion.raise(npc, 10)   # the Awakened are watching you now


func drift_label() -> String:
	return "Sharp" if drift < 20.0 else ("Getting comfortable" if drift < 45.0 else ("Settled in" if drift < 70.0 else "At home"))


## Dusk accounting. Playing a life well is pleasant, and pleasant is how the Hush wins.
## in_mood: the controlled person's mood (0..100) from the sim.
func close_day(in_mood: float, life_fidelity_bonus: float = 0.0) -> void:
	var fid := float(notes.get_note("fidelity"))
	# What keeps you awake is investigative progress today, not temperament.
	var progress := float(board.seals.size() - dawn_seals) * 4.0 + float(cracked_count() - dawn_cracks) * 3.0 + float(board.notebook.size() - dawn_photos) * 0.8
	var d := maxf(0.0, fid) / 8.0 + maxf(0.0, in_mood - 50.0) / 12.0 - progress
	drift = clampf(drift + d, 0.0, 100.0)
	contentment += maxf(0.0, in_mood - 40.0) * 0.1
	if fid >= 15.0:
		alignment += (fid / 10.0) + life_fidelity_bonus


## The morning hush: it edits the case file in proportion to how calm the town is and how comfortable you've got.
func hush_dawn() -> Array:
	if day <= int(board.edit_cfg["grace_days"]):
		return []
	var strength := hush_strength() * (0.4 + drift / 100.0)
	var n := int(round(strength * float(board.edit_cfg["max_per_dawn"]) * 2.0))
	return board.hush_edit(seed_for_day(), mini(n, int(board.edit_cfg["max_per_dawn"])))


func seed_for_day() -> int:
	return hash("hush|%d|%d" % [day, board.evidence.size()])


## Hints: Wren is a funny kid who tells you true things. The Prompter is calm, helpful, and steering you.
func pick_hint() -> Dictionary:
	var hints: Array = Data.load_json("hints.json")
	var p_prompter := clampf(0.2 + drift / 100.0 * 0.7, 0.0, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hint|%d|%d" % [day, int(drift)])
	var want_prompter := rng.randf() < p_prompter
	var pool: Array = hints.filter(func(h): return (h["voice"] == "prompter") == want_prompter and int(h["day_min"]) <= day)
	if pool.is_empty():
		pool = hints.filter(func(h): return int(h["day_min"]) <= day)
	var h: Dictionary = pool[rng.randi() % pool.size()]
	if h["voice"] == "prompter":
		flags["prompter_hints"] = int(flags.get("prompter_hints", 0)) + 1
	return h


func ending_for() -> String:
	var order := ["fair_water", "low_water", "same_time_tomorrow"]
	for key in order:
		var e: Dictionary = endings[key]
		var ok := true
		for s in e.get("requires_seals", []):
			if not board.seals.has(s):
				ok = false
		var layers: Dictionary = e.get("requires_layers", {})
		for layer in layers:
			if board.count_layer(layer) < int(layers[layer]):
				ok = false
		if ok:
			return key
	return "staying_day"


func to_dict() -> Dictionary:
	return {"version": 1, "day": day, "phase": int(phase), "notes": notes.to_dict(),
		"board": board.to_dict(), "suspicion": suspicion.values, "remnants": remnants.by_life,
		"mood": town_mood, "ending": ending, "flags": flags, "hosts": host_history, "next_host": next_host, "claims": claims, "drift": drift, "contentment": contentment, "alignment": alignment, "notoriety": notoriety}


func load_dict(d: Dictionary) -> void:
	day = int(d["day"])
	phase = int(d["phase"]) as Phase
	notes = Notes.from_dict(d["notes"])
	board.load_dict(d["board"])
	suspicion.values = d["suspicion"].duplicate()
	remnants.by_life = d["remnants"].duplicate(true)
	town_mood = int(d["mood"])
	ending = d["ending"]
	flags = d.get("flags", {}).duplicate()
	claims = d.get("claims", {}).duplicate()
	host_history = d.get("hosts", host_history).duplicate()
	next_host = d.get("next_host", "")
	drift = float(d.get("drift", 0.0)); contentment = float(d.get("contentment", 0.0)); alignment = float(d.get("alignment", 0.0)); notoriety = float(d.get("notoriety", 0.0))
	_enter_day_tools_only()


func _enter_day_tools_only() -> void:
	var keep := notes
	_enter_day()
	notes = keep


func save_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


func load_from(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or d.get("version", 0) != 1:
		return false
	load_dict(d)
	return true
