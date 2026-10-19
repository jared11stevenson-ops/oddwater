extends RefCounted
## At dusk the Chorus leaves a Remnant: the day's Notes harden into a walk-on.

const Notes = preload("res://scripts/core/notes.gd")

var tuning: Dictionary
var by_life: Dictionary = {}   # life id -> {day, notes, kept}


func _init(t: Dictionary) -> void:
	tuning = t


## `keep` is the note (with the Shed ability) the player chooses to keep at full
## strength; every other note decays. Pass "" for the default, which leaves all of them.
func step_off(life_id: String, day: int, notes: RefCounted, keep: String = "") -> Dictionary:
	var snap: RefCounted = notes.duplicate_notes()
	if keep != "":
		for k in Notes.KEYS:
			if k != keep:
				snap.values[k] = int(snap.values[k] * float(tuning["shed_decay"]))
	by_life[life_id] = {"day": day, "notes": snap.to_dict(), "kept": keep}
	return by_life[life_id]


func has_remnant(life_id: String) -> bool:
	return by_life.has(life_id)


## 0..1 liking, from WARMTH. Used to decide whether a Remnant will run its old Proof Tool for you.
func willing(life_id: String) -> bool:
	if not by_life.has(life_id):
		return false
	var n: Dictionary = by_life[life_id]["notes"]
	return int(n["warmth"]) >= 30 or int(n["nerve"]) >= 60
