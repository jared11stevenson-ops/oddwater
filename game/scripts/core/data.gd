extends RefCounted
## Loads the JSON that drives the game. Nothing is hard-coded in logic.

const DIR := "res://data/"


static func load_json(file: String) -> Variant:
	var f := FileAccess.open(DIR + file, FileAccess.READ)
	if f == null:
		push_error("Missing data file: %s" % file)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Bad JSON in %s" % file)
	return parsed


static func index_by(rows: Array, key: String) -> Dictionary:
	var out := {}
	for r in rows:
		out[r[key]] = r
	return out
