extends RefCounted
## The Cause. Every night it needs a host. It takes whoever is most ready to change.
## score = authored priority (so the story runs in order if nobody interferes) + restlessness * weight.
## The player can STEER by calming or unsettling people: two deliberate nudges flip adjacent candidates.

const Data = preload("res://scripts/core/data.gd")

var cfg: Dictionary
var lives: Array
var used: Array = []        # people already hosted (they don't come back as hosts, for now)


func _init() -> void:
	cfg = Data.load_json("cause.json")
	lives = Data.load_json("lives.json")


func priority_of(id: String) -> float:
	for l in lives:
		if l["id"] == id:
			return float(l["priority"])
	return 0.0


func score(sim: RefCounted, id: String) -> float:
	var p: RefCounted = sim.people.get(id)
	if p == null or not sim.alive(p):
		return -INF
	return priority_of(id) + (float(p.needs["restless"]) - 50.0) * float(cfg["restless_weight"])


## Candidates ranked best-first. `eligible` limits who can be taken (e.g. people with authored days).
## Priority is RELATIVE to who is left (an even step between neighbours), so steering stays as hard,
## and as possible, on the last night as on the first.
func ranking(sim: RefCounted, eligible: Array) -> Array:
	var left: Array = []
	for id in eligible:
		if used.has(id):
			continue
		var p: RefCounted = sim.people.get(id)
		if p != null and sim.alive(p):
			left.append(id)
	left.sort_custom(func(a, b): return priority_of(a) > priority_of(b))
	var out: Array = []
	var step := float(cfg.get("priority_step", 15.0))
	for i in left.size():
		var id: String = left[i]
		var eff := float(left.size() - 1 - i) * step
		out.append({"id": id, "score": eff + (float(sim.people[id].needs["restless"]) - 50.0) * float(cfg["restless_weight"])})
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	return out


func pick(sim: RefCounted, eligible: Array) -> String:
	var r := ranking(sim, eligible)
	return r[0]["id"] if not r.is_empty() else ""


func mark_used(id: String) -> void:
	if not used.has(id):
		used.append(id)


# ---------------------------------------------------------------- the player's lever: night actions on other people
## "comfort": sit with them, leave a meal, say the kind thing. "unsettle": a scare, bad news, an anonymous note.
func night_action(sim: RefCounted, action: String, target: String) -> Dictionary:
	var p: RefCounted = sim.people.get(target)
	if p == null or not sim.alive(p):
		return {"ok": false, "text": "nobody there"}
	match action:
		"comfort":
			p.needs["restless"] = clampf(float(p.needs["restless"]) - float(cfg["calm_amount"]), 0.0, 100.0)
			p.needs["social"] = clampf(float(p.needs["social"]) + 10.0, 0.0, 100.0)
			p.bump("player", 3.0, 2.0)
			return {"ok": true, "text": "%s is calmer for the company." % p.display}
		"unsettle":
			p.needs["restless"] = clampf(float(p.needs["restless"]) + float(cfg["unsettle_amount"]), 0.0, 100.0)
			p.needs["comfort"] = clampf(float(p.needs["comfort"]) - 15.0, 0.0, 100.0)
			p.remember(sim.day, "player", "was frightened in the night", 0.9)
			return {"ok": true, "text": "%s lies awake until dawn." % p.display}
	return {"ok": false, "text": "unknown"}


## Who looked like they were on the edge today. This is the player's *observation* of restlessness:
## the number is hidden but the behaviour isn't (staring at the lake, missed meals, bad mood).
func edge_report(sim: RefCounted, eligible: Array = []) -> Array:
	var out: Array = []
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		if not sim.alive(p) or (not eligible.is_empty() and (not eligible.has(id) or used.has(id))):
			continue
		var r := float(p.needs["restless"])
		if r >= (50.0 if not eligible.is_empty() else 55.0):
			var tell := "stares at the lake" if r >= 80.0 else ("has been short with everyone" if r >= 68.0 else "keeps checking the time")
			out.append({"id": id, "name": p.display, "tell": tell, "level": r})
	out.sort_custom(func(a, b): return a["level"] > b["level"])
	return out
