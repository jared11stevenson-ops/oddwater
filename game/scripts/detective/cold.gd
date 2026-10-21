extends RefCounted
## Cold cases. An unsolved murder does not wait for you: boots are thrown away, tracks wash out, weapons vanish, witnesses forget or leave,
## lab samples spoil, the Sheriff and the town lose patience, and after two weeks the file goes cold. The killer then runs, or strikes again.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Narrator = preload("res://scripts/detective/narrator.gd")

const GOES_COLD := 14


static func days_open(g: RefCounted) -> int:
	return int(g.sim.day) - int(g._truth.get("day", 0)) - 1


## Once a morning. `g` is the DetectiveGame.
static func tick(g: RefCounted) -> void:
	var c: Dictionary = g._truth
	var n := days_open(g)
	if c.get("status", "") != "open" or Serial.active(g.serial) or g.court.get("custody", "") != "" or n < 2:
		return
	var cold: Dictionary = c["cold"]
	if int(cold.get("day", -1)) == int(g.sim.day):
		return
	cold["day"] = int(g.sim.day)
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	# the physical trail
	_gone(c, det, "c_foot", n >= 3)
	_gone(c, det, "c_weapon", n >= (5 if c["weapon_at"]["public"] else 7))
	_gone(c, det, "c_k_shoes", n >= 6)
	_gone(c, det, "c_k_coat", n >= 6)
	# witnesses forget, and one leaves town
	for fid in c["facts"]:
		var f: Dictionary = c["facts"][fid]
		if f["topic"] == "saw" and not det.has(fid) and not f.get("faded", false) and absi(hash("%s|%d" % [fid, n])) % 100 < 12 * (n - 2):
			f["faded"] = true
	if n >= 7 and not cold.get("left", false):
		for fid in c["facts"]:
			var f2: Dictionary = c["facts"][fid]
			if f2["topic"] == "saw" and not det.has(fid) and not f2["knowers"].is_empty() and f2["knowers"][0] != c["killer"]:
				var w: RefCounted = sim.people[f2["knowers"][0]]
				if sim.alive(w):
					w.taken = true
					w.location = ""
					cold["left"] = true
					g.today.append("%s has left Little Mercy, to stay with family. What %s saw went with them." % [w.display, CaseEngine.first(sim, w.id)])
					break
	# the Sheriff, the town
	if n >= 3:
		Reputation.apply(det, "cold_drain", int(sim.day))
	if n >= 6 and n % 2 == 0:
		Reputation.apply(det, "cold_drain_town", int(sim.day))
	if n in [3, 6, 9, 12]:
		var lines := {3: "Three days. The Sheriff has stopped asking how it is going and started asking when.", 6: "A week, nearly. The Courier has printed the dead person's name twice and yours once, in a smaller font.", 9: "Nine days. The footprints are gone, the sample is a smear, and the people who saw things have begun to remember them differently.", 12: "Twelve days. The Sheriff puts the file on the corner of the desk where files go to be put in drawers."}
		g.pending_beats.append({"title": "THE FILE GROWS COLD", "text": lines[n]})
	if n >= GOES_COLD:
		_go_cold(g)


static func _gone(c: Dictionary, det: RefCounted, cid: String, cond: bool) -> void:
	if cond and c["clues"].has(cid) and not det.has(cid):
		c["clues"][cid]["gone"] = true


static func _go_cold(g: RefCounted) -> void:
	var c: Dictionary = g._truth
	var sim: RefCounted = g.sim
	c["status"] = "cold"
	c["closed_day"] = int(sim.day)
	Reputation.apply(g.det, "cold_case", int(sim.day))
	g.det.cases_failed += 1
	var ep: Dictionary = Narrator.episode(sim, c, g.det, {"verdict": "cold", "score": 0, "right_person": false})
	g.episodes.append(ep)
	g.chronicle.append({"day": sim.day, "text": "The case of %s went cold." % CaseEngine.name_of(sim, c["victim"])})
	var k: String = c["killer"]
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|cold|%s" % [g.seed_v, c["id"]])
	if r.randf() < 0.45:
		var pk: RefCounted = sim.people[k]
		pk.taken = true
		pk.location = ""
		c["status"] = "fled"
		sim.log_event("vacancy", k, "%s is gone." % pk.display)
		g.today.append("%s has left Little Mercy in the night. The house is empty and the kettle is cold." % pk.display)
	else:
		g.repeat_killer = k
		g.today.append("The file on %s is closed. In a house you pass every day, someone is sleeping very well." % CaseEngine.name_of(sim, c["victim"]))
