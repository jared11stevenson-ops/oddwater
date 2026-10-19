extends RefCounted
## A town-hall speech: three crowd segments react to each beat. No fail state: a cold room is a story outcome.

const Data = preload("res://scripts/core/data.gd")

var def: Dictionary
var seg: Dictionary = {}
var beat := 0
var flags: Dictionary = {}
var notes_gain: Dictionary = {}


func _init(id: String) -> void:
	def = Data.load_json("speech/speeches.json")[id]
	seg = def["segments"].duplicate()


func beat_def() -> Dictionary:
	return def["beats"][beat]


func finished() -> bool:
	return beat >= def["beats"].size()


func mood() -> float:
	var m := 0.0
	for k in def["weights"]:
		m += float(seg[k]) * float(def["weights"][k])
	return m


## Pick a choice for the current beat; returns the effects dict applied.
func choose(i: int) -> Dictionary:
	if finished():
		return {}
	var cs: Array = beat_def()["choices"]
	if i < 0 or i >= cs.size():
		return {}
	var c: Dictionary = cs[i]
	for k in c["fx"]:
		seg[k] = clampi(int(seg[k]) + int(c["fx"][k]), 0, 100)
	for k in c.get("notes", {}):
		notes_gain[k] = int(notes_gain.get(k, 0)) + int(c["notes"][k])
	if c.has("flag"):
		flags[c["flag"]] = true
	beat += 1
	return c


func outcome() -> String:
	var m := mood()
	return "warm" if m >= 58.0 else ("mixed" if m >= 42.0 else "cold")


func outcome_text() -> String:
	return {"warm": "The room is with you. Even Hank sits down, slowly, as if the chair had been moved.",
		"mixed": "The room is split. Half of them clap. The other half study their hands.",
		"cold": "The room goes quiet in the way a lake does just before it does something."}[outcome()]
