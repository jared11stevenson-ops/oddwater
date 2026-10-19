extends RefCounted
## "Small Paths": a child's day has a budget of listening. Pick where to spend it.
## Some spots only open after another has been heard (the grown-ups' day unfolds).

const Data = preload("res://scripts/core/data.gd")

var map: Dictionary
var budget := 0
var heard: Dictionary = {}


func _init(map_id: String) -> void:
	map = Data.load_json("eavesdrop.json")[map_id]
	budget = int(map["budget"])


func spot(id: String) -> Dictionary:
	for s in map["spots"]:
		if s["id"] == id:
			return s
	return {}


## Why a spot cannot be used now, or "".
func block_reason(id: String) -> String:
	var s := spot(id)
	if s.is_empty():
		return "unknown"
	if heard.has(id):
		return "heard"
	if budget <= 0:
		return "no_time"
	if s.has("requires") and not heard.has(s["requires"]):
		return "locked"
	return ""


## Listen. Returns the spot dict (with "ok": true) or {"ok": false, "reason": ...}.
func listen(id: String) -> Dictionary:
	var why := block_reason(id)
	if why != "":
		return {"ok": false, "reason": why}
	budget -= 1
	heard[id] = true
	var out: Dictionary = spot(id).duplicate(true)
	out["ok"] = true
	return out
