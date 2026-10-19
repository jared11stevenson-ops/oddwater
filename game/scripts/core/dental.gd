extends RefCounted
## The Dental Overlay Proof Tool: lay a patient's X-ray over an old chart and flag teeth whose
## restorations match (same kind, material and maker's mark). Cozy by design: a wrong flag costs
## "doubt", never the run. Proof needs `need` genuine matches.

const Data = preload("res://scripts/core/data.gd")

var case_def: Dictionary
var flagged: Dictionary = {}     # tooth -> true (correct matches)
var wrong: Dictionary = {}       # tooth -> true
var doubt := 0


func _init(case_id: String) -> void:
	case_def = Data.load_json("dental/cases.json")[case_id]


func tooth_current(t: int) -> Dictionary:
	return case_def["current"].get(str(t), {})


func tooth_record(t: int) -> Dictionary:
	return case_def["record"].get(str(t), {})


func matches(t: int) -> bool:
	var a := tooth_current(t)
	var b := tooth_record(t)
	return not a.is_empty() and a == b


func true_matches() -> Array:
	var out: Array = []
	for t in range(1, 33):
		if matches(t):
			out.append(t)
	return out


## Flag a tooth. Returns "match", "miss" or "again".
func flag(t: int) -> String:
	if t < 1 or t > 32:
		return "miss"
	if flagged.has(t) or wrong.has(t):
		return "again"
	if matches(t):
		flagged[t] = true
		return "match"
	wrong[t] = true
	doubt += 1
	return "miss"


func proven() -> bool:
	return flagged.size() >= int(case_def["need"]) and not true_matches().is_empty()


## The case has nothing to prove (e.g. a human patient with no record). Valid, informative outcome.
func is_clean_case() -> bool:
	return true_matches().is_empty()


func verdict() -> String:
	return case_def["verdict_match"] if proven() else case_def["verdict_none"]
