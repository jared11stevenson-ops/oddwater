extends RefCounted
## Where it happened, in its own words. A kitchen is a kitchen and a sheriff's office is a sheriff's office: every scene gets the
## room, the smell and the wrongness of the kind of place it really is.

const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Prose = preload("res://scripts/detective/prose.gd")


static func _pl() -> Dictionary:
	return Prose.json("detective/places.json")


static func _r(c: Dictionary, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s|%s" % [c.get("id", ""), c.get("seed", 0), salt])
	return r


static func kind_of_lot(lot: String, scene_kind: String = "work") -> String:
	if scene_kind == "home":
		return "home"
	return String(_pl()["types"].get(lot, "generic"))


## {type, label, room, sense, plan, key} for the case's scene. Deterministic for the case.
static func profile(c: Dictionary) -> Dictionary:
	var pl: Dictionary = _pl()
	var t := kind_of_lot(String(c.get("scene", "")), String(c.get("scene_kind", "home")))
	var k: Dictionary = pl["kinds"].get(t, pl["kinds"]["generic"])
	var r := _r(c, "place")
	var key: String = String(pl["unease_key"].get(t, t))
	return {"type": t, "label": k["label"], "room": k["rooms"][r.randi() % k["rooms"].size()], "sense": k["senses"][r.randi() % k["senses"].size()],
		"plan": k["plans"][r.randi() % k["plans"].size()], "key": key}


static func _pool(group: String, key: String) -> Array:
	var h: Dictionary = Prose.json("detective/horror.json")
	var g: Dictionary = h[group]
	var out: Array = (g.get(key, []) as Array).duplicate()
	if out.is_empty() or key != "home":
		out.append_array(g.get("generic", []))
	return out


static func unease(c: Dictionary, victim_first: String) -> String:
	var p := profile(c)
	var pool: Array = _pool("unease", p["key"])
	var r := _r(c, "unease")
	return String(pool[r.randi() % pool.size()]).replace("{v}", victim_first)


static func diary(c: Dictionary, victim_first: String) -> String:
	var p := profile(c)
	var pool: Array = _pool("diaries", p["key"])
	var r := _r(c, "diary")
	return String(pool[r.randi() % pool.size()]).replace("{v}", victim_first)


## A lore fragment (the lake, the Hush, 4:12) woven into about one scene in three.
static func lore(c: Dictionary, victim_first: String) -> String:
	var r := _r(c, "lore")
	if r.randf() > 0.4 and not bool(c.get("serial", false)):
		return ""
	var pool: Array = Prose.json("detective/horror.json")["lore"]
	return String(pool[r.randi() % pool.size()]).replace("{v}", victim_first)


## "the kitchen of Okafor's place", "the bake room at The Rising Loaf": a real room in the real place.
static func where_phrase(sim: RefCounted, c: Dictionary) -> String:
	var p := profile(c)
	var pn: String = Brief.place_name(sim, c["scene"], "")
	if p["type"] == "home":
		return "%s of %s" % [p["room"], pn]
	return "%s at %s" % [p["room"], pn]
