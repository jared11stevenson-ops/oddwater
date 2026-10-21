extends RefCounted
## False confessors. Once a serial killer's work is in the paper, the lonely, the attention-starved and the broken start walking into the
## station to say it was them. Their stories are plausible and wrong: they get the hour or the method wrong and cannot name the one
## signature detail that was never printed. The detective may arrest them; the held-back test (or a session in the interview room)
## exposes the story. An untested confession can convict, and a conviction on a false confession is a scandal that lets the killer strike again.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Claims = preload("res://scripts/detective/claims.gd")

const MAX_PER_SERIAL := 3
const CHANCE := 0.45


static func entry_id(id: String) -> String:
	return "falseconf_" + id


## Who has confessed on this case (from the case file, so a save keeps them).
static func list(c: Dictionary) -> Array:
	return c.get("confessors", [])


static func is_false(c: Dictionary, id: String) -> bool:
	return list(c).any(func(x): return x["id"] == id)


static func entry_for(det: RefCounted, id: String) -> Dictionary:
	if det.known.has(entry_id(id)):
		return det.known[entry_id(id)]
	for kid in det.order:       # a new body opens a new file and the old entries keep their place under that case's name
		if String(kid).ends_with(":" + entry_id(id)):
			return det.known[kid]
	return {}


static func untested(det: RefCounted, id: String) -> bool:
	var e: Dictionary = entry_for(det, id)
	return not e.is_empty() and not e.get("tested", false)


## Does a false confession stand in the notebook, not yet exposed?
static func any_untested(c: Dictionary, det: RefCounted) -> bool:
	return list(c).any(func(x): return untested(det, x["id"]))


## Maybe someone confesses this morning. Needs a hunting serial killer with the news out and an open case. Returns the notebook entry or {}.
static func roll(sim: RefCounted, c: Dictionary, det: RefCounted, serial: Dictionary, court: Dictionary, seed_v: int, day: int) -> Dictionary:
	if String(serial.get("status", "")) != "hunting" or int(serial.get("third_day", -1)) < 0 or day < int(serial["third_day"]):
		return {}
	if String(c.get("status", "")) != "open":
		return {}
	if int(serial.get("confessions", 0)) >= MAX_PER_SERIAL:
		return {}
	if list(c).any(func(x): return untested(det, x["id"])):
		return {}      # one at a time
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|confessor|%d" % [seed_v, day])
	if r.randf() >= CHANCE:
		return {}
	var best := ""
	var best_s := -1e9
	for id in sim.order:
		if id == "player" or id == c["killer"] or id == c["victim"] or id in c["suspects"]:
			continue
		var p: RefCounted = sim.people[id]
		if not sim.alive(p) or p.jailed or p.taken or court.get("custody", "") == id or is_false(c, id) or not (p.group in ["adult", "elder"]):
			continue
		if (serial.get("confessed", []) as Array).has(id):
			continue
		# the broken, the lonely and the restless; ties broken by a stable hash
		var s: float = float(p.needs["restless"]) - float(p.needs["comfort"]) - float(p.needs["social"]) * 0.5 + float(absi(hash("%d|%s|%d" % [seed_v, id, day])) % 40)
		if s > best_s:
			best_s = s
			best = id
	if best == "":
		return {}
	return make(sim, c, det, serial, best, r, day)


static func make(sim: RefCounted, c: Dictionary, det: RefCounted, serial: Dictionary, id: String, r: RandomNumberGenerator, day: int) -> Dictionary:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var d: Dictionary = Prose.json("detective/confessors.json")
	var real_h: float = float(c["hour"])
	var said_h: float = real_h - r.randf_range(3.0, 4.5) if r.randf() < 0.5 else real_h + r.randf_range(3.0, 4.5)
	var methods: Array = (cb["methods"] as Dictionary).keys().filter(func(m): return m != c["method"])
	var said_m: String = methods[r.randi() % methods.size()]
	var mm: Dictionary = cb["methods"][said_m]
	var weapons: Array = mm["weapons"]
	var weapon: String = weapons[r.randi() % weapons.size()]
	var nm: String = CaseEngine.name_of(sim, id)
	var tale: String = String((d["tales"] as Array)[r.randi() % (d["tales"] as Array).size()])
	tale = tale.replace("{time}", CaseEngine._time(said_h)).replace("{weapon}", weapon).replace("{method_line}", String(mm["wound"]))
	var sign_line: String = String((d["vague_sign"] as Array)[r.randi() % (d["vague_sign"] as Array).size()]).replace("{n}", CaseEngine.first(sim, id))
	var walk: String = String((d["walkins"] as Array)[r.randi() % (d["walkins"] as Array).size()]).replace("{n}", nm).replace("{nick}", String(serial.get("nick", "the killer")))
	var text := "%s\n\n%s\n\nBut %s." % [walk, tale, sign_line]
	var e := {"id": entry_id(id), "title": "Confession: %s" % CaseEngine.first(sim, id), "kind": "confession", "source": id, "day": day, "text": text,
		"tested": false, "said_hour": said_h, "said_method": said_m, "guess": String((d["guesses"] as Array)[r.randi() % (d["guesses"] as Array).size()])}
	e["claims"] = Claims.emit(c, [Claims.make("said", id, "confessed_story", "", said_h, "", 0.8, "false")], id, text)
	det.learn(e)
	if not c.has("confessors"):
		c["confessors"] = []
	(c["confessors"] as Array).append({"id": id, "day": day})
	serial["confessions"] = int(serial.get("confessions", 0)) + 1
	if not serial.has("confessed"):
		serial["confessed"] = []
	(serial["confessed"] as Array).append(id)
	return e


static func headline(sim: RefCounted, serial: Dictionary, id: String, day: int) -> String:
	var d: Dictionary = Prose.json("detective/confessors.json")
	var hs: Array = d["headlines"]
	return String(hs[absi(hash("%s|%d" % [id, day])) % hs.size()]).replace("{n}", CaseEngine.name_of(sim, id).to_upper()).replace("{nick_u}", String(serial.get("nick", "KILLER")).to_upper())


## The held-back detail test: compare the story to the scene. A false confession fails it (wrong hour, wrong method, no signature).
## It turns the notebook entry unreliable and records an exoneration. Returns {ok, text, exposed, learned}.
static func test(sim: RefCounted, c: Dictionary, det: RefCounted, id: String) -> Dictionary:
	var e: Dictionary = entry_for(det, id)
	if e.is_empty():
		return {"ok": false, "text": "There is no confession from that person to test.", "exposed": false, "learned": []}
	if e.get("tested", false):
		return {"ok": true, "text": "You have already held this story against the scene. It does not fit.", "exposed": true, "learned": []}
	var d: Dictionary = Prose.json("detective/confessors.json")
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var line: String = String((d["exposed"] as Array)[absi(hash(id)) % (d["exposed"] as Array).size()])
	line = line.replace("{n}", CaseEngine.first(sim, id)).replace("{guess}", String(e.get("guess", "A card"))).replace("{said_time}", CaseEngine._time(float(e["said_hour"]))).replace("{real_time}", CaseEngine._time(float(c["hour"]))) \
		.replace("{said_method}", String(cb["methods"][e["said_method"]]["wound"])).replace("{real_method}", String(cb["methods"][c["method"]]["wound"]))
	e["tested"] = true
	e["claims"] = Claims.emit(c, [Claims.make("said", id, "confession_disproved", "", -1.0, "", 1.0, "true")], id, String(e["text"]))
	var note := {"id": "falseconf_note_" + id, "title": "%s: not the killer" % CaseEngine.first(sim, id), "kind": "testimony", "source": id, "day": int(sim.day),
		"text": "The story fails the held-back test: wrong hour, wrong method, and the signature is a guess lifted from the paper. %s is lonely, not guilty." % CaseEngine.first(sim, id)}
	note["claims"] = Claims.emit(c, [Claims.make("found", id, "observation")], id, String(note["text"]))
	var learned: Array = []
	if det.learn(note):
		learned.append(note)
	return {"ok": true, "text": line, "exposed": true, "learned": learned}


## A conviction on an untested false confession: the killer is emboldened and strikes tonight. (The reputation cost is paid in Justice.conclude.)
static func convicted_wrongly(serial: Dictionary, day: int) -> void:
	if String(serial.get("status", "")) == "hunting":
		serial["next_strike"] = mini(int(serial.get("next_strike", day)), day)
		serial["emboldened"] = int(serial.get("emboldened", 0)) + 1
