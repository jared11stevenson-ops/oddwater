extends RefCounted
## Dedication Hour: each caller gets a song. The first letters of the right songs spell FAIRW.
## (The playlist sheet carries the next nights: A, T, E, R. Together: FAIR WATER.)

const Data = preload("res://scripts/core/data.gd")

var def: Dictionary
var picked: Dictionary = {}   # slot -> option index


func _init(id: String) -> void:
	def = Data.load_json("radio/sets.json")[id]


func slot_count() -> int:
	return def["slots"].size()


func choose(slot: int, opt: int) -> bool:
	if slot < 0 or slot >= slot_count():
		return false
	var s: Dictionary = def["slots"][slot]
	if opt < 0 or opt >= s["options"].size():
		return false
	picked[slot] = opt
	return opt == int(s["correct"])


func letters() -> String:
	var out := ""
	for i in slot_count():
		if picked.has(i):
			out += String(def["slots"][i]["options"][picked[i]]).substr(0, 1).to_upper()
		else:
			out += "_"
	return out


func correct_count() -> int:
	var n := 0
	for i in picked:
		if int(picked[i]) == int(def["slots"][i]["correct"]):
			n += 1
	return n


func complete() -> bool:
	return picked.size() == slot_count()


## Did the player notice the pattern? (Every dedication right.)
func spells() -> bool:
	return complete() and letters() == String(def["answer"])


func stars() -> int:
	var c := correct_count()
	return 3 if c >= slot_count() else (2 if c >= slot_count() - 1 else (1 if c >= 2 else 0))
