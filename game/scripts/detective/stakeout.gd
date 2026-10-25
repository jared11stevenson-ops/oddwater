extends RefCounted
## Stakeouts. Park outside a home or a place and watch for a window of hours. The town clock really advances, half an hour at a time, and
## the sim's own movements are what you see: who comes and who goes, seen (a name, as sure as the light allows) or unseen (a figure). The
## notes you take are claims. It costs you: patience and sleep, and a chance of being spotted that costs rapport and may tip off a
## suspect, who then clears their house. Light matters: dusk and dark hide faces, and a poor look can put the wrong name on a figure.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Brief = preload("res://scripts/sim/brief.gd")

const MAX_HOURS := 6


static func light_at(h: float) -> float:
	if h < 17.5:
		return 1.0
	if h < 20.0:
		return 0.85
	if h < 22.0:
		return 0.65
	return 0.5


static func hours_available(g: RefCounted) -> int:
	if g.phase != "day" or g.sim.day_over():
		return 0
	return mini(int(floor(g.hours_left())), MAX_HOURS)


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


static func _rng(g: RefCounted, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|watch|%d|%s" % [g.seed_v, int(g.sim.day), salt])
	return r


## `lot` is the building you park outside; `hours` how long you stay. Returns {ok, text, learned, spotted, hours, minutes}.
static func run(g: RefCounted, lot: String, hours: int) -> Dictionary:
	var d: Dictionary = Prose.json("detective/watch.json")
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	var c: Dictionary = g._truth
	if not g.layout.by_id.has(lot):
		return {"ok": false, "text": "There is nothing there to watch.", "learned": [], "hours": 0, "minutes": 0}
	var room: int = hours_available(g)
	if room <= 0:
		return {"ok": false, "text": "It is too late in the day to start a watch. The street will be there tomorrow.", "learned": [], "hours": 0, "minutes": 0}
	hours = clampi(hours, 1, room)
	var walk: Dictionary = g.travel_to(lot)
	var left: int = mini(hours, int(floor(g.hours_left())))
	if left <= 0:
		return {"ok": false, "text": "By the time you get there the light is gone and so is the day.", "learned": [], "hours": 0, "minutes": int(walk.get("minutes", 0))}
	hours = left
	var place: String = g.place_name(lot)
	var home_of := ""
	for id in sim.order:
		if sim.people[id].home == lot and id != "player" and sim.alive(sim.people[id]):
			home_of = String(id)
			break
	var prev := _present(sim, lot)
	var start_h: float = sim.hour_now()
	var lines: Array = [_pick(d["park"], "%s|%s" % [lot, start_h]).replace("{place}", place)]
	var tmpl: Array = []
	var obs: int = det.skill("observation")
	var staying := prev.duplicate()
	var spotted := false
	var spotter := ""
	var events := 0
	for tick in hours * 2:
		var h_before: float = sim.hour_now()
		g.spend(30)
		g.flush_time()
		var h: float = sim.hour_now()
		var now := _present(sim, lot)
		var rnd := _rng(g, "%s|%d" % [lot, tick])
		for id in now:
			if not prev.has(id):
				events += _event(g, d, tmpl, lines, String(id), lot, place, h_before + 0.25, true, obs, rnd)
		for id2 in prev:
			if not now.has(id2):
				events += _event(g, d, tmpl, lines, String(id2), lot, place, h_before + 0.25, false, obs, rnd)
				staying.erase(id2)
		for id3 in staying.duplicate():
			if not now.has(id3):
				staying.erase(id3)
		# the chance of being seen: a parked car is a parked car
		var sp_p: float = clampf((0.12 if h < 17.5 else (0.09 if h < 20.0 else 0.05)) * 0.5 - 0.006 * float(obs - 3), 0.01, 0.2)
		if not spotted and rnd.randf() < sp_p:
			spotted = true
			spotter = home_of if home_of != "" and (now.has(home_of) or h < 22.0) else (String(now[0]) if not now.is_empty() else "")
			lines.append(_pick(d["spotted"], "%s|%d" % [lot, tick]))
		prev = now
	# the alerted killer clears the house at dusk: a watcher may catch it
	var killer_home: String = String(sim.people[String(c["killer"])].home) if sim.people.has(String(c["killer"])) else ""
	if bool(c.get("alerted", false)) and lot == killer_home and start_h + float(hours) >= 19.0 and _rng(g, "bundle").randf() < 0.6 and not bool(c.get("bundle_seen", false)):
		c["bundle_seen"] = true
		var bt: float = maxf(start_h + 0.5, 19.0)
		lines.append(_pick(d["bundle"], lot).replace("{n}", CaseEngine.first(sim, String(c["killer"]))).replace("{t}", Brief.clock_text(bt)))
		tmpl.append(Claims.make("seen", String(c["killer"]), "carried_bundle", lot, bt, "", 0.7))
		events += 1
	if events == 0:
		lines.append(_pick(d["kept"] if home_of != "" and prev.has(home_of) else d["quiet"], lot + "|q"))
		if home_of != "" and prev.has(home_of):
			tmpl.append(Claims.make("seen", home_of, "kept_house", lot, start_h, "", 0.55))
		else:
			tmpl.append(Claims.make("seen", "", "observation", lot, start_h, "", 0.8))
	# the cost: sleep, nerves, patience
	var me: RefCounted = g.me()
	var dark: bool = start_h + float(hours) > 20.0
	det.add_stress(float(hours) * (3.0 if dark else 1.5))
	me.needs["energy"] = clampf(float(me.needs["energy"]) - 5.0 * float(hours), 0.0, 100.0)
	if hours >= 3:
		lines.append(_pick(d["tired"], "%s|%d" % [lot, hours]))
	if spotted:
		_tip(g, c, lot, home_of, spotter)
	var text := Prose.clean("\n".join(lines))
	var e := {"id": "watch_%s_%d_%d" % [lot, int(sim.day), int(start_h * 2)], "title": "Watched %s" % place, "text": text, "kind": "watch", "source": lot, "day": int(sim.day)}
	e["claims"] = Claims.emit(c, tmpl, lot, text)
	var learned: Array = []
	if det.learn(e):
		learned.append(e)
		det.gain_xp(8 + 3 * events)
	return {"ok": true, "text": text, "learned": learned, "spotted": spotted, "hours": hours, "minutes": hours * 60 + int(walk.get("minutes", 0)), "events": events}


static func _present(sim: RefCounted, lot: String) -> Array:
	var out: Array = []
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		if id != "player" and sim.alive(p) and not p.taken and not p.jailed and p.location == lot:
			out.append(String(id))
	return out


## One coming or going: seen well enough to name, or only a figure. In the dark a poor look can put the wrong name on a stranger.
static func _event(g: RefCounted, d: Dictionary, tmpl: Array, lines: Array, who: String, lot: String, place: String, t: float, arrive: bool, obs: int, rnd: RandomNumberGenerator) -> int:
	var sim: RefCounted = g.sim
	var light: float = light_at(t)
	var chance: float = clampf(light * 0.92 + 0.04 * float(obs - 3), 0.2, 0.97)
	var clock := Brief.clock_text(fposmod(t, 24.0))
	var roll: float = rnd.randf()
	if roll < chance:
		var named := who
		var tag := "true"
		if light < 0.6 and rnd.randf() < 0.1:         # a poor look at a stranger: you put the wrong name on them
			var others: Array = CaseEngine.neighbors(sim, lot, 6, [who, "player", String(g.case.get("victim", ""))])
			if not others.is_empty():
				named = String(others[rnd.randi() % others.size()])
				tag = "false"
		var cert: float = 0.55 + 0.35 * light
		var key: String = "arrived" if arrive else "left"
		lines.append(_pick(d[key], "%s|%s|%d" % [who, lot, int(t * 10)]).replace("{n}", CaseEngine.name_of(sim, named)).replace("{t}", clock).replace("{place}", place))
		tmpl.append(Claims.make("seen", named, "arrived_at" if arrive else "left_from", lot, t, "", cert, tag))
	else:
		var fig: String = _pick(d["figures"], "%s|%d" % [who, int(t * 10)])
		lines.append(_pick(d["unseen_in" if arrive else "unseen_out"], "%s|%s|%d" % [who, lot, int(t * 10)]).replace("{t}", clock).replace("{place}", place))
		tmpl.append(Claims.make("seen", "", "figure_seen", lot, t, fig, 0.45))
	return 1


## Being spotted: the person watched trusts you less, and a killer who sees you clears out the evidence you have not yet found.
static func _tip(g: RefCounted, c: Dictionary, lot: String, home_of: String, spotter: String) -> void:
	var sim: RefCounted = g.sim
	if spotter != "" and sim.people.has(spotter):
		sim.people[spotter].bump("player", -8.0, -6.0)
		sim.people[spotter].remember(int(sim.day), "player", "sat in a parked car outside, watching", 2.0)
	g.det.add_stress(2.0)
	var k: String = String(c.get("killer", ""))
	var killer_home: String = String(sim.people[k].home) if sim.people.has(k) else ""
	if spotter == k or lot == killer_home or (home_of == k):
		c["alerted"] = true
		c["killer_alert"] = int(c.get("killer_alert", 0)) + 1
		for cid in ["c_k_shoes", "c_k_coat", "c_weapon"]:
			if c["clues"].has(cid) and not g.det.has(cid):
				c["clues"][cid]["gone"] = true
