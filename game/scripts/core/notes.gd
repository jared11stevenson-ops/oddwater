extends RefCounted
## The five Notes a performance leaves behind (WARMTH, CANDOR, NERVE, CURIOSITY, FIDELITY).

const KEYS: Array[String] = ["warmth", "candor", "nerve", "curiosity", "fidelity"]
const LIMIT := 100

var values: Dictionary = {}


func _init() -> void:
	for k in KEYS:
		values[k] = 0


func add(key: String, amount: int) -> void:
	if not KEYS.has(key):
		push_error("Unknown note: %s" % key)
		return
	values[key] = clampi(int(values[key]) + amount, -LIMIT, LIMIT)


func get_note(key: String) -> int:
	return int(values.get(key, 0))


## The note with the largest absolute value, or "" if the performance was flat.
func dominant() -> String:
	var best := ""
	var best_abs := 0
	for k in KEYS:
		var a := absi(int(values[k]))
		if a > best_abs:
			best_abs = a
			best = k
	return best


func duplicate_notes() -> RefCounted:
	var n: RefCounted = get_script().new()
	n.values = values.duplicate()
	return n


func to_dict() -> Dictionary:
	return values.duplicate()


static func from_dict(d: Dictionary) -> RefCounted:
	var n: RefCounted = load("res://scripts/core/notes.gd").new()
	for k in KEYS:
		n.values[k] = clampi(int(d.get(k, 0)), -LIMIT, LIMIT)
	return n
