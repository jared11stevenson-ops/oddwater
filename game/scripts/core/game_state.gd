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
var honesty_pull := 0   # a child's fibs build up; at 100 the truth blurts out (resets each day)


func _init() -> void:
	tuning = Data.load_json("tuning.json")
	lives = Data.load_json("lives.json")
	endings = Data.load_json("endings.json")
	board = CaseBoard.new()
	suspicion = Suspicion.new(tuning)
	remnants = Remnants.new(tuning)
	notes = Notes.new()
	_enter_day()


func current_life() -> Dictionary:
	return lives[mini(day, lives.size()) - 1]


func is_foggy() -> bool:
	return town_mood < int(tuning["fog_below_mood"])


## Hush strength 0..1: strong when the town is calm.
func hush_strength() -> float:
	return clampf(town_mood / 100.0, 0.0, 1.0)


func _enter_day() -> void:
	notes = Notes.new()
	honesty_pull = 0
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
				day += 1
				phase = Phase.WAKE
				_enter_day()
	return phase


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
		"mood": town_mood, "ending": ending}


func load_dict(d: Dictionary) -> void:
	day = int(d["day"])
	phase = int(d["phase"]) as Phase
	notes = Notes.from_dict(d["notes"])
	board.load_dict(d["board"])
	suspicion.values = d["suspicion"].duplicate()
	remnants.by_life = d["remnants"].duplicate(true)
	town_mood = int(d["mood"])
	ending = d["ending"]
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
