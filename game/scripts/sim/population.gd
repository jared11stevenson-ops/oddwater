extends RefCounted
## Generates the town's everyday residents: households in the generic house lots, each person with an age, a job at a real
## workplace (or school, or retirement), days off, a hobby, favourite haunts and a quirk. Same templates, different people.
## Deterministic for a seed. Output matches data/sim/people.json plus a few extra keys, and a list of relationships.

const Data = preload("res://scripts/core/data.gd")

var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var people: Array = []
var relations: Array = []
var _slots: Dictionary = {}       # workplace -> slots left
var _used_names: Dictionary = {}
var _n := 0


func generate(seed_value: int, layout: RefCounted, taken_names: Array = []) -> Dictionary:
	cfg = Data.load_json("sim/population.json")
	rng.seed = hash("population|%d" % seed_value)
	for w in cfg["workplaces"]:
		_slots[w["place"]] = int(w["slots"])
	for nm in taken_names:
		_used_names[nm] = true
	var houses: Array = layout.lots.filter(func(l): return l["kind"] == "house")
	houses.sort_custom(func(a, b): return a["id"] < b["id"])
	var prev: Array = []      # people of the previous house, for neighbour ties
	for h in houses:
		var members := _household(h["id"])
		_tie_household(members)
		for m in members:
			for q in prev:
				if rng.randf() < 0.15:
					_rel(m["id"], q["id"], rng.randf_range(5, 25), rng.randf_range(5, 20))
		prev = members
	_tie_colleagues()
	_tie_classmates()
	return {"people": people, "relations": relations}


func _weighted(items: Array, key: String = "weight") -> Dictionary:
	var total := 0.0
	for it in items:
		total += float(it[key])
	var r := rng.randf() * total
	for it in items:
		r -= float(it[key])
		if r <= 0.0:
			return it
	return items[-1]


func _name(surname: String = "") -> Array:
	for tries in 40:
		var f: String = cfg["first_names"][rng.randi() % cfg["first_names"].size()]
		var s: String = surname if surname != "" else cfg["surnames"][rng.randi() % cfg["surnames"].size()]
		if not _used_names.has(f + " " + s):
			_used_names[f + " " + s] = true
			return [f, s]
	return ["Pat", "Doe%d" % _n]


func _household(home_id: String) -> Array:
	var kind: String = _weighted(cfg["households"])["kind"]
	var surname: String = cfg["surnames"][rng.randi() % cfg["surnames"].size()]
	var m: Array = []
	match kind:
		"single": m.append(_person(home_id, surname, rng.randi_range(22, 62), "adult"))
		"couple":
			var a := rng.randi_range(25, 60)
			m.append(_person(home_id, surname, a, "adult"))
			m.append(_person(home_id, surname, clampi(a + rng.randi_range(-6, 6), 22, 66), "adult"))
		"family":
			var a2 := rng.randi_range(30, 52)
			m.append(_person(home_id, surname, a2, "adult"))
			m.append(_person(home_id, surname, clampi(a2 + rng.randi_range(-5, 5), 26, 58), "adult"))
			for k in rng.randi_range(1, 3):
				var ka := rng.randi_range(5, 17)
				m.append(_person(home_id, surname, ka, "teen" if ka >= 13 else "child"))
		"single_parent":
			m.append(_person(home_id, surname, rng.randi_range(28, 50), "adult"))
			for k in rng.randi_range(1, 2):
				var ka2 := rng.randi_range(5, 16)
				m.append(_person(home_id, surname, ka2, "teen" if ka2 >= 13 else "child"))
		"elder_alone": m.append(_person(home_id, surname, rng.randi_range(66, 91), "elder"))
		"elder_couple":
			var e := rng.randi_range(66, 86)
			m.append(_person(home_id, surname, e, "elder"))
			m.append(_person(home_id, surname, clampi(e + rng.randi_range(-4, 4), 64, 90), "elder"))
		"roommates":
			for k in rng.randi_range(2, 3):
				var nm := _name()
				m.append(_person(home_id, nm[1], rng.randi_range(19, 30), "adult", nm))
	for p in m:
		p["household"] = kind
	return m


func _person(home_id: String, surname: String, age: int, group: String, nm: Array = []) -> Dictionary:
	_n += 1
	if nm.is_empty():
		nm = _name(surname)
	var hobby_keys: Array = cfg["hobbies"].keys()
	hobby_keys.sort()
	var hobby: String = hobby_keys[rng.randi() % hobby_keys.size()]
	var p := {"id": "r%03d" % _n, "name": "%s %s" % [nm[0], nm[1]], "home": home_id, "work": "", "job": "", "wake": 0.0,
		"work_start": 0.0, "work_end": 0.0, "faction": "", "walkon": true, "secret": "", "money": 0.0,
		"age": age, "group": group, "hobby": hobby, "quirk": cfg["quirks"][rng.randi() % cfg["quirks"].size()],
		"days_off": [], "haunts": [], "household": "",
		"traits": {"sociable": _t(), "honest": _t(), "bold": _t(), "pious": _t() * 0.8, "thrift": _t()}}
	var jitter := rng.randf_range(-0.75, 0.75)
	match group:
		"child", "teen":
			p["work"] = "school"; p["job"] = "student"
			p["wake"] = 6.5 + rng.randf_range(0.0, 0.75) + (0.5 if group == "teen" else 0.0)
			p["work_start"] = 8.0 + (0.5 if group == "teen" else 0.0); p["work_end"] = 15.0
			p["days_off"] = [5, 6]
			p["money"] = float(rng.randi_range(0, 30 if group == "teen" else 8))
		"elder":
			p["job"] = "retired"
			p["wake"] = 5.75 + rng.randf_range(0.0, 1.25)
			p["money"] = float(rng.randi_range(300, 2400))
		_:
			_give_job(p, jitter)
	p["haunts"] = _haunts(p)
	people.append(p)
	return p


func _t() -> float:
	return clampf(rng.randfn(0.5, 0.2), 0.05, 0.95)


func _give_job(p: Dictionary, jitter: float) -> void:
	var r := rng.randf()
	if r < 0.07:
		p["job"] = "unemployed"
		p["wake"] = 8.0 + rng.randf_range(0.0, 2.0)
		p["money"] = float(rng.randi_range(5, 120))
		return
	if r < 0.15:
		p["job"] = cfg["remote_titles"][rng.randi() % cfg["remote_titles"].size()]
		p["work"] = p["home"]
		p["wake"] = 7.0 + rng.randf_range(0.0, 1.75)
		p["work_start"] = 9.0 + rng.randf_range(0.0, 1.0); p["work_end"] = p["work_start"] + 7.5
		p["days_off"] = [5, 6]
		p["money"] = float(rng.randi_range(200, 1800))
		return
	var open: Array = cfg["workplaces"].filter(func(w): return int(_slots[w["place"]]) > 0)
	if open.is_empty():
		p["job"] = "odd jobs"; p["wake"] = 8.0; p["money"] = 60.0
		return
	var w: Dictionary = open[rng.randi() % open.size()]
	_slots[w["place"]] = int(_slots[w["place"]]) - 1
	p["work"] = w["place"]
	p["job"] = w["titles"][rng.randi() % w["titles"].size()]
	p["work_start"] = clampf(float(w["start"]) + (rng.randf_range(-0.5, 0.5) if float(w["start"]) > 6.0 else 0.0), 4.0, 20.0)
	p["work_end"] = clampf(float(w["end"]) + rng.randf_range(-0.5, 0.5), p["work_start"] + 4.0, 23.5)
	p["wake"] = maxf(p["work_start"] - rng.randf_range(0.9, 1.8), 3.5)
	p["days_off"] = w["days_off"].duplicate()
	p["money"] = float(rng.randi_range(80, 900)) * (float(w["pay"]) / 24.0)
	p["pay"] = float(w["pay"])


## 3 favourite places: the hobby's places, a social venue, and one more. This is what makes lives look different.
func _haunts(p: Dictionary) -> Array:
	var out: Array = []
	for pl in cfg["hobbies"][p["hobby"]]["places"]:
		out.append(p["home"] if pl == "home" else pl)
	var venues: Array = cfg["social_venues"]
	var tries := 0
	while out.size() < 4 and tries < 20:
		tries += 1
		var v: String = venues[(rng.randi() + int(float(p["traits"]["sociable"]) * 7.0)) % venues.size()]
		if not out.has(v):
			out.append(v)
	return out


func _rel(a: String, b: String, aff: float, trust: float) -> void:
	relations.append({"a": a, "b": b, "affinity": aff, "trust": trust})


func _tie_household(m: Array) -> void:
	for i in m.size():
		for j in range(i + 1, m.size()):
			var a: Dictionary = m[i]
			var b: Dictionary = m[j]
			var kids: bool = a["group"] in ["child", "teen"] or b["group"] in ["child", "teen"]
			if kids and not (a["group"] in ["child", "teen"] and b["group"] in ["child", "teen"]):
				_rel(a["id"], b["id"], rng.randf_range(65, 92), rng.randf_range(70, 95))   # parent and child
			elif kids:
				_rel(a["id"], b["id"], rng.randf_range(35, 80), rng.randf_range(45, 85))    # siblings fight and love
			elif a["household"] in ["roommates"]:
				_rel(a["id"], b["id"], rng.randf_range(10, 60), rng.randf_range(20, 60))
			else:
				_rel(a["id"], b["id"], rng.randf_range(55, 90), rng.randf_range(60, 90))


func _tie_colleagues() -> void:
	var by_work: Dictionary = {}
	for p in people:
		if p["work"] != "" and p["work"] != p["home"]:
			by_work.get_or_add(p["work"], []).append(p)
	for w in by_work:
		var staff: Array = by_work[w]
		for i in staff.size():
			for j in range(i + 1, staff.size()):
				if staff[i]["group"] == "adult" and staff[j]["group"] == "adult" or w != "school":
					if rng.randf() < 0.5:
						_rel(staff[i]["id"], staff[j]["id"], rng.randf_range(8, 45), rng.randf_range(10, 45))


func _tie_classmates() -> void:
	var kids: Array = people.filter(func(p): return p["job"] == "student")
	for i in kids.size():
		for k in 3:
			var j := rng.randi() % kids.size()
			if j != i and absi(int(kids[i]["age"]) - int(kids[j]["age"])) <= 2 and kids[i]["home"] != kids[j]["home"]:
				_rel(kids[i]["id"], kids[j]["id"], rng.randf_range(15, 70), rng.randf_range(15, 60))
