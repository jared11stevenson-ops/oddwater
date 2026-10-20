extends RefCounted
## Today's wishes for whoever you are: three small things this particular person would want from the day, built from their own life.
## Nothing forces them. Doing them makes the person's day better (mood, purpose, restlessness), and the Lives report remembers.

const Brief = preload("res://scripts/sim/brief.gd")
const Relationship = preload("res://scripts/sim/relationship.gd")

const POINTS := 10


static func _rng(sim: RefCounted, id: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("wish|%d|%d|%s" % [sim.seed_base, sim.day, id])
	return r


## Choose up to three wishes that make sense for this person today.
static func generate(sim: RefCounted, id: String) -> Array:
	var p: RefCounted = sim.people[id]
	var pool: Array = []
	pool.append({"id": "meal", "text": "Have a proper meal"})
	if sim.on_shift(p, p.work_start) and p.work != "" and p.work != p.home:
		pool.append({"id": "shift", "text": "Put in a full %s (6+ hours)" % ("day at school" if p.job == "student" else "shift")})
		pool.append({"id": "shift", "text": "Put in a full %s (6+ hours)" % ("day at school" if p.job == "student" else "shift")})
	for oid in sim.order:
		var o: RefCounted = sim.people[oid]
		if oid != id and o.home == p.home and sim.alive(o):
			pool.append({"id": "family", "text": "Talk to %s" % o.display, "target": oid})
	var strained: Array = []
	for oid in p.rel:
		if sim.people.has(oid) and sim.alive(sim.people[oid]) and p.affinity(oid) <= -10.0:
			strained.append(oid)
	if not strained.is_empty():
		var t: String = strained[_rng(sim, id).randi() % strained.size()]
		pool.append({"id": "mend", "text": "Be kind to %s" % sim.people[t].display, "target": t})
		pool.append({"id": "mend", "text": "Be kind to %s" % sim.people[t].display, "target": t})
	if not p.haunts.is_empty():
		pool.append({"id": "haunt", "text": "Spend time at %s" % Brief.place_name(sim, p.haunts[0], id), "target": p.haunts[0]})
	if sim.weather_today() in ["clear", "cloudy"]:
		pool.append({"id": "outdoors", "text": "Get some fresh air"})
	if p.money < 120.0 and p.employed:
		pool.append({"id": "earn", "text": "Earn some money (+$50)"})
	if p.money > 150.0:
		pool.append({"id": "treat", "text": "Treat someone to something"})
	pool.append({"id": "friend", "text": "Make a new friend"})
	pool.append({"id": "company", "text": "Spend time with a friend"})
	# draw three distinct kinds, deterministic
	var r := _rng(sim, id)
	var out: Array = []
	var kinds: Dictionary = {}
	var guard := 0
	while out.size() < 3 and not pool.is_empty() and guard < 60:
		guard += 1
		var i := r.randi() % pool.size()
		var w: Dictionary = pool[i]
		if kinds.has(w["id"]):
			continue
		kinds[w["id"]] = true
		var wc: Dictionary = w.duplicate()
		wc["done"] = false
		wc["points"] = POINTS
		out.append(wc)
	return out


## Is this wish done, given what you've done today? `st` is TownGame's running tally.
static func check(sim: RefCounted, id: String, w: Dictionary, st: Dictionary) -> bool:
	var p: RefCounted = sim.people[id]
	match String(w["id"]):
		"meal": return int(st.get("ate", 0)) > 0
		"shift": return int(st.get("work_ticks", 0)) >= 12
		"family": return st.get("talked", {}).has(w["target"])
		"mend": return st.get("kind_to", {}).has(w["target"])
		"haunt": return int(st.get("ticks_at", {}).get(w["target"], 0)) >= 2
		"outdoors": return int(st.get("outdoor_ticks", 0)) >= 2
		"earn": return p.money - float(st.get("money_start", p.money)) >= 50.0
		"treat": return not st.get("gifts", {}).is_empty()
		"friend":
			for oid in st.get("talked", {}):
				if sim.people.has(oid) and st["talked"][oid] > 0 and float(st.get("aff_start", {}).get(oid, 0.0)) < 25.0:
					return true
			return false
		"company":
			for oid in st.get("talked", {}):
				if sim.people.has(oid) and p.affinity(oid) >= 25.0:
					return true
			return false
	return false
