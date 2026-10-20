extends RefCounted
## The case engine. It reads the living town, picks a victim and a killer whose real relationship makes a motive plausible,
## writes the recent past into the sim (arguments, rumours, grudges), decides the night, and builds the web of clues, witnesses
## and lies that lets a player work it out. Everything is deterministic for a seed. A case is a dictionary (the truth).

const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Relationship = preload("res://scripts/sim/relationship.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Places = preload("res://scripts/detective/places.gd")

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


static func _rng(seed_v: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%s" % [seed_v, salt])
	return r


static func _pick(r: RandomNumberGenerator, a: Array) -> Variant:
	return a[r.randi() % a.size()]


## A low-discrepancy number in [0,1) for (seed, day): consecutive seeds spread evenly instead of clumping, so the motives, methods and
## cast sizes across a run of cases stay balanced instead of lopsided.
static func _strat(seed_v: int, day: int, stride: float, off: float) -> float:
	return fposmod(float(seed_v) * stride + float(day) * 0.2360679775 + off, 1.0)


static func dayname(c: Dictionary, offset: int) -> String:
	return DAYS[(int(c["day"]) + offset) % 7]


static func _forms(thing: String) -> Array:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	return cb["forms"].get(thing, [thing, thing, thing])


## The same motive three ways: as a noun phrase ("the unpaid loan"), as the victim's own words to the killer, and a short tag.
static func thing_about(thing: String) -> String:
	return String(_forms(thing)[0])


static func thing_quote(thing: String, killer_first: String) -> String:
	return String(_forms(thing)[1]).replace("{k}", killer_first)


static func thing_short(thing: String) -> String:
	return String(_forms(thing)[2])


static func name_of(sim: RefCounted, id: String) -> String:
	return sim.people[id].display if sim.people.has(id) else id


static func first(sim: RefCounted, id: String) -> String:
	return String(name_of(sim, id)).split(" ")[0]


static func _adults(sim: RefCounted) -> Array:
	return sim.order.filter(func(id):
		var p: RefCounted = sim.people[id]
		# a newcomer needs a few days to be woven into town before a story can be built on them
		return id != "player" and sim.alive(p) and p.group in ["adult", "elder"] and p.age >= 25 and p.home != "" and not (id.begins_with("n") and int(sim.day) - int(p.arrived_day) < 6))


static func _dist(lot_a: String, lot_b: String) -> float:
	var l: Dictionary = Brief.layout().by_id
	if not l.has(lot_a) or not l.has(lot_b):
		return 9999.0
	return Vector2(float(l[lot_a]["x"]), float(l[lot_a]["y"])).distance_to(Vector2(float(l[lot_b]["x"]), float(l[lot_b]["y"])))


## Residents whose homes are closest to `lot`, nearest first.
static func neighbors(sim: RefCounted, lot: String, n: int, exclude: Array = []) -> Array:
	var cands: Array = []
	for id in _adults(sim):
		var p: RefCounted = sim.people[id]
		if exclude.has(id) or p.home == lot:
			continue
		cands.append({"id": id, "d": _dist(p.home, lot)})
	cands.sort_custom(func(a, b): return a["d"] < b["d"])
	return cands.slice(0, n).map(func(x): return x["id"])


static func _relation_type(sim: RefCounted, v: String, k: String) -> String:
	var pv: RefCounted = sim.people[v]
	var pk: RefCounted = sim.people[k]
	if pv.home == pk.home:
		return "family"
	if pv.work != "" and pv.work == pk.work and pv.work != pv.home:
		return "money"
	if _dist(pv.home, pk.home) < 70.0:
		return "grudge"
	return "passion" if pk.affinity(v) >= 20.0 else "grudge"


static func trace_for(job: String) -> String:
	var j := job.to_lower()
	if "baker" in j or "counter" in j:
		return "flour dust"
	if "cook" in j or "dishwasher" in j or "server" in j:
		return "kitchen grease"
	if "hygienist" in j or "dent" in j:
		return "dental wax"
	if "boat" in j or "ferry" in j or "dock" in j or "marina" in j:
		return "fish scales and diesel"
	if "nurse" in j or "orderly" in j or "care" in j:
		return "antiseptic"
	if "teach" in j or "school" in j or "student" in j:
		return "chalk dust"
	if "mail" in j or "clerk" in j or "records" in j:
		return "printer ink"
	if "garden" in j or "grounds" in j:
		return "potting soil"
	return "grey cotton lint"


static func _time(h: float) -> String:
	return Brief.clock_text(fposmod(h, 24.0))


# =========================================================================== generate
## opts (serial killers): killer, signature (the held-back detail), trait, thread (index into casebook threads), avoid (earlier victims),
## n (how many people this killer has already killed: the first scenes are the cleanest).
static func generate(sim: RefCounted, seed_v: int, day: int, opts: Dictionary = {}) -> Dictionary:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var r := _rng(seed_v, "case%d" % day)
	var adults := _adults(sim)
	var serial: bool = opts.has("killer")
	# ---- who, and why: the pair whose real relationship makes a motive plausible
	var pairs: Array = []
	for i in 40:
		var v: String = _pick(r, adults)
		var pv: RefCounted = sim.people[v]
		for k in pv.rel:
			if k == v or not adults.has(k):
				continue
			var t := _relation_type(sim, v, k)
			var w := r.randf() + (0.2 if t == "money" else (0.15 if t == "grudge" else (0.2 if t == "family" else (0.25 if t == "passion" else 0.0))))
			pairs.append({"v": v, "k": k, "type": t, "w": w})
	if pairs.is_empty():
		var a: String = adults[0]
		var b: String = adults[-1]
		pairs.append({"v": a, "k": b, "type": "grudge", "w": 1.0})
	pairs.sort_custom(func(x, y): return x["w"] > y["w"])
	var pair: Dictionary = pairs[0]
	var victim: String = pair["v"]
	var killer: String = pair["k"]
	# the motive is drawn evenly across the run, not from whatever the relationship happens to suggest (inheritance only within a family)
	var motive: String
	var um := _strat(seed_v, day, 0.6180339887, 0.13)
	if pair["type"] == "family":
		motive = "family" if um < 0.7 else ["money", "silence", "grudge"][int(um * 10.0) % 3]
	else:
		motive = ["grudge", "money", "silence", "passion"][int(um * 4.0) % 4]
	if serial:
		killer = opts["killer"]
		motive = "grudge"
		var cands: Array = adults.filter(func(id): return id != killer and sim.people[id].home != sim.people[killer].home and not (opts.get("avoid", []) as Array).has(id))
		cands.sort_custom(func(a, b): return _dist(sim.people[a].home, sim.people[killer].home) > _dist(sim.people[b].home, sim.people[killer].home))
		victim = cands[r.randi() % mini(cands.size(), 12)]
	elif opts.has("force_killer"):
		killer = opts["force_killer"]
		var cands2: Array = adults.filter(func(id): return id != killer and not (opts.get("avoid", []) as Array).has(id) and sim.people[killer].rel.has(id))
		if cands2.is_empty():
			cands2 = adults.filter(func(id): return id != killer)
		victim = cands2[r.randi() % cands2.size()]
	var pv: RefCounted = sim.people[victim]
	var pk: RefCounted = sim.people[killer]
	# ---- where: the victim's home if they live alone, otherwise their workplace
	var scene_kind := "home"
	var scene: String = pv.home
	var housemates: Array = sim.order.filter(func(id): return id != victim and sim.people[id].home == pv.home and sim.alive(sim.people[id]))
	if (not housemates.is_empty() or r.randf() < 0.3) and pv.work != "" and pv.work != pv.home:
		scene_kind = "work"
		scene = pv.work
	var hour := r.randf_range(25.0, 27.6)
	var methods: Array = cb["methods"].keys()
	methods.sort()
	var method: String = methods[int(_strat(seed_v, day, 0.4142135624, 0.71) * float(methods.size())) % methods.size()]
	var m: Dictionary = cb["methods"][method]
	var weapon: String = _pick(r, m["weapons"])
	var thing: String = _pick(r, cb["motives"][motive]["things"])
	var trait_k: String = _pick(r, cb["traits"])
	var item: String = _pick(r, cb["dropped"])
	var shoes: String = _pick(r, cb["shoes"])
	var gloves: bool = r.randf() < (0.88 if serial else 0.3)
	var held: String = _pick(r, cb["held_back"])
	if serial:
		held = opts["signature"]
		trait_k = opts["trait"]
		thing = "the verdict of years ago, and a name that was never forgiven"
	var c := {"gloves": gloves, "held_back": held, "id": "case_%d" % day, "day": day, "seed": seed_v, "victim": victim, "killer": killer, "motive": motive, "motive_thing": thing,
		"method": method, "weapon": weapon, "scene": scene, "scene_kind": scene_kind, "hour": hour, "trait": trait_k, "item": item, "shoes": shoes,
		"trace": trace_for(pk.job), "facts": {}, "clues": {}, "profiles": {}, "suspects": [], "keyholders": [], "weapon_at": {}, "status": "planned",
		"accusations": 0, "accused": [], "cold": {}, "voice_used": {}}
	if opts.has("n"):
		c["n_prior"] = int(opts["n"])
	# ---- the cast around the crime
	var used: Array = [victim, killer]
	var finder := ""
	if scene_kind == "work":
		for id in sim.order:
			if id != victim and sim.alive(sim.people[id]) and sim.people[id].work == scene and not used.has(id):
				finder = id
				break
	if finder == "":
		var hm: Array = housemates.filter(func(x): return x != killer)
		var nb: Array = neighbors(sim, scene, 1, used)
		finder = hm[0] if not hm.is_empty() else (nb[0] if not nb.is_empty() else "")
	used.append(finder)
	c["found_by"] = finder
	c["found_hour"] = 6.5 + r.randf() * 0.8
	c["found_rel"] = _found_relation(sim, finder, victim)
	var vn: Array = neighbors(sim, scene, 2, used)
	used.append_array(vn)
	var kn: Array = [] if serial else neighbors(sim, pk.home, 2, used)
	used.append_array(kn)
	# red herrings: two to four people with their own reasons to be suspicious, and sometimes one more who comes into view only later
	var us := _strat(seed_v, day, 0.7320508076, 0.37)
	var nh := 2 if us < 0.2 else (3 if us < 0.6 else 4)
	var with_shadow: bool = _strat(seed_v, day, 0.5773502692, 0.52) < 0.4
	var herrings: Array = []
	var rel_ids: Array = []
	for id in pv.rel:
		if adults.has(id) and not used.has(id):
			rel_ids.append(id)
	rel_ids.sort_custom(func(a, b): return pv.affinity(a) < pv.affinity(b))
	for id in rel_ids:
		if herrings.size() < nh:
			herrings.append(id)
	var guard := 0
	while herrings.size() < nh and guard < 60:
		guard += 1
		var cand: String = _pick(r, adults)
		if not used.has(cand) and not herrings.has(cand):
			herrings.append(cand)
	used.append_array(herrings)
	var shadow := ""
	if with_shadow:
		var sh: Array = neighbors(sim, scene, 8, used)
		if not sh.is_empty():
			shadow = sh[r.randi() % mini(sh.size(), 4)]
			used.append(shadow)
	c["suspects"] = [killer] + herrings
	c["herring_ids"] = herrings.duplicate()
	c["shadow"] = shadow
	# ---- the suspects' real nights, and what they will say
	_profiles(sim, c, cb, r, herrings, used)
	_facts_and_clues(sim, c, cb, r, vn, kn, used)
	_cameras_prints_family(sim, c, r, vn, kn)
	if shadow != "":
		_shadow(sim, c, cb, r, shadow, used)
	_misdirection(sim, c, cb, r, used)
	if serial:
		c["serial"] = true
		c["thread"] = cb["threads"][int(opts.get("thread", 0)) % cb["threads"].size()]
		_serial_tweaks(sim, c, int(opts.get("n", 0)))
	return c


## How the finder is tied to the dead, as a noun to follow "<victim>'s": housemate, colleague, close friend, neighbour.
static func _found_relation(sim: RefCounted, finder: String, victim: String) -> String:
	if finder == "" or not sim.people.has(finder):
		return "neighbour"
	var f: RefCounted = sim.people[finder]
	var v: RefCounted = sim.people[victim]
	if f.home == v.home and f.home != "":
		return "housemate"
	if f.work != "" and f.work == v.work:
		return "colleague"
	var aff: float = f.affinity(victim)
	if aff >= 50.0:
		return "close friend"
	if aff >= 20.0:
		return "neighbour and friend"
	return "neighbour"


## A serial killer is harder, and the first scenes are the hardest: nothing dropped, no prints, no key, no family to break, no
## neighbour who saw them go and a decoy that points the wrong way. The thread that links the dead shows only from the second body; a mistake
## or two appears from the third. What links the victims is one old photograph, and the same strange detail is left at every scene.
static func _serial_tweaks(sim: RefCounted, c: Dictionary, n: int) -> void:
	var k: String = c["killer"]
	var v: String = c["victim"]
	var vname := name_of(sim, v)
	for fid in ["f_argument", "f_trait_k", "f_kn_saw", "f_lead_kn", "f_confidant"]:
		c["facts"].erase(fid)
	for cid in ["c_callrecord"]:
		c["clues"].erase(cid)
	c["keyholders"] = [v, c["found_by"]]
	c["relatives"][k] = []
	c["avoids_cams"] = n < 2
	c["helper"] = n >= 1
	var door: Dictionary = c["clues"]["c_door"]
	door["title"] = "A forced window"
	door["text"] = "The back window was jimmied from outside, cleanly. Whoever came did not need a key."
	door["supports"] = []
	var desk: Dictionary = c["clues"]["c_desk"]
	if n >= 1:
		desk["text"] = "In the desk drawer, %s. Every other name on it has a line through it, and %s's is next to last." % [c["thread"]["photo"], vname]
		desk["supports"] = [_sup("motive", k, 1)]
		desk["thread"] = true
	else:
		desk["text"] = "Papers, bills, a pen with the cap chewed. Nothing here says why anyone would want %s dead." % first(sim, v)
		desk["supports"] = []
	var phone: Dictionary = c["clues"]["c_phone"]
	phone["text"] = "The phone's memory shows a call at %s from the payphone outside the post office. Nobody answered but the line stayed open a minute." % _time(float(c["hour"]) - 1.5)
	phone["supports"] = [_sup("time", "", 1)]
	if c["clues"].has("c_timeline"):
		c["clues"]["c_timeline"]["supports"] = [_sup("motive", k, 1)] if n >= 2 else []
	var ppl: Array = sim.order.filter(func(id): return id != k and id != v and id != c["found_by"] and sim.alive(sim.people[id]) and sim.people[id].age >= 55 and not c["suspects"].has(id))
	if not ppl.is_empty() and n >= 1:
		_fact(c, "f_thread_motive", c["thread"]["gossip"] + " %s was one of them. So, I think, was %s." % [vname, first(sim, k)], "victim", ppl.slice(0, 2), "rapport", [_sup("motive", k, 3)], k)
	if n < 2:
		# clean scenes: nothing dropped, no prints in the soft ground, nothing at home worth a warrant, nobody who knows the killer's things
		for cid in ["c_dropped", "c_foot", "c_k_shoes"]:
			c["clues"].erase(cid)
		c["lab"] = {}
		c["facts"].erase("f_owner")
		c["facts"].erase("f_owns")
		c["owner_item_knowers"] = []
		c["latents"] = c["latents"].filter(func(l): return l["owner"] != k)
	if n < 1 and c["herring_ids"].size() > 0:
		# a decoy: the first body looks like an ordinary murder with an ordinary, loud suspect
		var d: String = c["herring_ids"][-1]
		c["decoy_first"] = d
		var dn := first(sim, d)
		_fact(c, "f_decoy_row", "%s and %s had a shouting match on the green the night before. I heard the word 'sorry' and the word 'never' and I'd say they meant both." % [dn, first(sim, v)], "victim", neighbors(sim, c["scene"], 3, [k, v, d, c["found_by"]]).slice(0, 2), "free", [_sup("motive", d, 2), _sup("opportunity", d, 1)], d)
		c["profiles"][d]["decoy_for_serial"] = true
	if n >= 1:
		_fact(c, "f_helper_hint", "%s came to see me the day after. Very concerned. Said you should look at the people %s had quarrelled with. A bit eager, I thought." % [first(sim, k), first(sim, v)], "suspects", [k], "free", [], k)


# --------------------------------------------------------------------------- profiles
static func _profiles(sim: RefCounted, c: Dictionary, cb: Dictionary, r: RandomNumberGenerator, herrings: Array, used: Array) -> void:
	var killer: String = c["killer"]
	var victim: String = c["victim"]
	var hk: float = c["hour"]
	c["profiles"][killer] = {"role": "killer", "alibi": "false", "claim": "", "claim_kind": "claim_killer", "lie": true,
		"night": {"lot": c["scene"], "from": hk - 0.75, "to": hk + 0.75}, "tell": "keeps checking the door"}
	# red herring 1: a secret night elsewhere, and a lie to hide it
	var h1: String = herrings[0]
	var secrets: Array = cb["secrets"].keys()
	secrets.sort()
	var st: String = _pick(r, secrets)
	var sec: Dictionary = cb["secrets"][st]
	var partner := ""
	var secret_lot: String = sec["place"]
	if st == "affair":
		var cands := neighbors(sim, sim.people[h1].home, 6, used + [h1])
		partner = cands[0] if not cands.is_empty() else victim
		used.append(partner)
		secret_lot = sim.people[partner].home
	var witness_for_secret := ""
	var staff: Array = sim.order.filter(func(id): return sim.people[id].work == secret_lot and not used.has(id) and sim.alive(sim.people[id]))
	if st == "affair":
		witness_for_secret = partner
	elif not staff.is_empty():
		witness_for_secret = staff[0]
		used.append(witness_for_secret)
	else:
		var wn := neighbors(sim, secret_lot, 1, used)
		witness_for_secret = wn[0] if not wn.is_empty() else killer
		used.append(witness_for_secret)
	c["profiles"][h1] = {"role": "herring", "alibi": "secret", "secret_type": st, "secret_text": String(sec["text"]).replace("{p}", first(sim, partner) if partner != "" else "someone"),
		"secret_why": sec["why"], "claim": "", "claim_kind": "claim_secret", "lie": true, "partner": partner, "secret_lot": secret_lot,
		"confirmer": witness_for_secret, "cult": bool(sec.get("cult", false)), "night": {"lot": secret_lot, "from": hk - 2.2, "to": hk + 1.6}, "tell": "won't hold your eye"}
	# red herring 2: a solid alibi, confirmed by someone else
	var h2: String = herrings[1]
	var alibi_lots: Array = cb["alibi_places"].keys()
	alibi_lots.sort()
	var al: String = _pick(r, alibi_lots)
	var staff2: Array = sim.order.filter(func(id): return sim.people[id].work == al and not used.has(id) and sim.alive(sim.people[id]))
	var confirmer2 := ""
	if not staff2.is_empty():
		confirmer2 = staff2[0]
	else:
		var wn2 := neighbors(sim, al, 1, used)
		confirmer2 = wn2[0] if not wn2.is_empty() else killer
	used.append(confirmer2)
	c["profiles"][h2] = {"role": "herring", "alibi": "verified", "claim": "", "claim_kind": "claim_verified", "where": cb["alibi_places"][al], "lie": false, "alibi_lot": al,
		"confirmer": confirmer2, "night": {"lot": al, "from": hk - 3.0, "to": hk + 2.0}, "tell": "calm, a little offended"}
	# red herring 3: no alibi, a petty reason, and nothing else
	if herrings.size() > 2:
		var h3: String = herrings[2]
		c["profiles"][h3] = {"role": "herring", "alibi": "weak", "claim": "", "claim_kind": "claim_weak", "lie": false, "night": {"lot": sim.people[h3].home, "from": hk - 1.0, "to": hk + 1.0}, "tell": "defensive, but honest"}
	# red herring 4: the decoy, with a real reason, the right kind of tool in the house, and a night that does not clear them at once
	if herrings.size() > 3:
		var h4: String = herrings[3]
		var al4: String = _pick(r, alibi_lots)
		c["profiles"][h4] = {"role": "decoy", "alibi": "shaky", "claim": "", "claim_kind": "claim_weak", "lie": false, "alibi_lot": sim.people[h4].home,
			"night": {"lot": sim.people[h4].home, "from": hk - 1.0, "to": hk + 1.0}, "tell": "angry, then afraid"}
		var cn4 := neighbors(sim, sim.people[h4].home, 2, used + [h4])
		c["profiles"][h4]["confirmer"] = cn4[0] if not cn4.is_empty() else killer
		used.append(c["profiles"][h4]["confirmer"])
	for id in c["profiles"]:
		c["profiles"][id]["id"] = id
	_write_claims(sim, c)


## The first things each suspect says about their night: voiced for the person, not stamped from one template.
static func _write_claims(sim: RefCounted, c: Dictionary) -> void:
	var Voice = load("res://scripts/detective/voice.gd")
	for id in c["profiles"]:
		var pr: Dictionary = c["profiles"][id]
		pr["claim"] = Voice.say(String(pr.get("claim_kind", "claim_weak")), sim, c, id, {"where": pr.get("where", "somewhere"), "v": first(sim, c["victim"])})


# --------------------------------------------------------------------------- facts and clues
static func _fact(c: Dictionary, id: String, text: String, topic: String, knowers: Array, reveal: String, supports: Array, about: String = "") -> void:
	c["facts"][id] = {"id": id, "text": text, "topic": topic, "knowers": knowers, "reveal": reveal, "supports": supports, "about": about}


static func _clue(c: Dictionary, id: String, title: String, text: String, lot: String, spot: String, gate: Dictionary, supports: Array, extra: Dictionary = {}) -> void:
	var d := {"id": id, "title": title, "text": text, "lot": lot, "spot": spot, "gate": gate, "supports": supports}
	d.merge(extra, true)
	c["clues"][id] = d


static func _sup(cat: String, about: String, strength: int) -> Dictionary:
	return {"cat": cat, "about": about, "strength": strength}


const HOBBY_STOPPED := {"fishing": "going out fishing", "gardening": "tending the garden", "reading": "going to the library", "music": "playing", "sports": "going to the games",
	"walking": "their evening walks", "gaming": "their weekly game night", "crafts": "working on their crafts", "baking": "baking", "regular": "going to their regular table",
	"birding": "going out birding", "volunteering": "volunteering"}


static func _facts_and_clues(sim: RefCounted, c: Dictionary, cb: Dictionary, r: RandomNumberGenerator, vn: Array, kn: Array, used: Array) -> void:
	var v: String = c["victim"]
	var k: String = c["killer"]
	var vname := name_of(sim, v)
	var kname := name_of(sim, k)
	var pv: RefCounted = sim.people[v]
	var pk: RefCounted = sim.people[k]
	var scene: String = c["scene"]
	var hk: float = c["hour"]
	var m: Dictionary = cb["methods"][c["method"]]
	var h1: String = ""
	var h2: String = ""
	var h3: String = ""
	var h4: String = ""
	for id in c["suspects"]:
		match String(c["profiles"][id].get("alibi", "")):
			"secret": h1 = id
			"verified": h2 = id
			"weak": h3 = id
			"shaky": h4 = id
	var vfirst := first(sim, v)
	var about_thing := thing_about(c["motive_thing"])
	# ---------------- the physical scene
	_clue(c, "c_body", "The body", "%s lies where they fell. %s. They have been dead some hours." % [vname, Prose.sentence(String(m["wound"]))], scene, "body", {"skill": "forensics", "level": 1}, [_sup("method", c["method"], 3)])
	_clue(c, "c_odd", "The detail that doesn't fit", "%s. Nothing else in the room is out of place." % c["held_back"], scene, "body", {"skill": "observation", "level": 2}, [], {"held_back": true})
	_clue(c, "c_time", "Time of death", "Body temperature and stiffness put the death between %s and %s." % [_time(hk - 1.0), _time(hk + 1.0)], scene, "body", {"skill": "forensics", "level": 2}, [_sup("time", "", 2)])
	# the wrongness: what the room itself seems to know, and what the victim had been feeling in their last weeks (both by kind of place)
	var unease_text := Places.unease(c, vfirst)
	var lore := Places.lore(c, vfirst)
	if lore != "":
		unease_text += " " + lore
	_clue(c, "c_unease", "The room is wrong", unease_text, scene, "body", {"skill": "empathy", "level": 3}, [], {"eerie": true})
	_clue(c, "c_diary", "The last pages", Places.diary(c, vfirst), scene, "desk", {"skill": "empathy", "level": 2}, [], {"eerie": true})
	var keyholders := [v, k]
	if not c["found_by"] in keyholders:
		keyholders.append(c["found_by"])
	c["keyholders"] = keyholders
	_clue(c, "c_door", "No forced entry", "The locks are intact. Whoever came in was let in, or had a key. Keys are held by %s." % Prose.list_join(keyholders.map(func(x): return name_of(sim, x))), scene, "door", {"skill": "observation", "level": 2}, keyholders.map(func(x): return _sup("opportunity", x, 1)))
	var where: String = String(_pick(r, cb["dropped_where"]))
	_clue(c, "c_dropped", "Something dropped", "%s %s" % [where.replace("{i}", c["item"]), _pick(r, cb["dropped_state"])], scene, "floor", {"skill": "observation", "level": 2}, [_sup("link", k, 1)], {"lab": true})
	_clue(c, "c_foot", "Footprints in the soft ground", "A clear print by the path: %s. Someone stood here a while." % c["shoes"], scene, "garden", {"skill": "observation", "level": 2}, [])
	var kf := first(sim, k)
	var desk_text := ""
	match c["motive"]:
		"grudge": desk_text = "A drawer of drafts: angry letters to %s about %s. None sent. One says 'I'll make you sorry'." % [kname, about_thing]
		"money": desk_text = "An IOU signed by %s, and a note to self: 'Call %s's bluff Friday. Or the sheriff.' Concerning %s." % [kname, kf, about_thing]
		"family": desk_text = "A solicitor's draft concerning %s. %s is named in the old will and struck from the new one." % [about_thing, kname]
		"silence": desk_text = "Notes in a hand that shakes: '%s' The page is dated this week." % thing_quote(c["motive_thing"], kf)
		"passion": desk_text = "A half-written letter: '%s'" % thing_quote(c["motive_thing"], kf)
	var desk_sup := [_sup("motive", k, 1)]
	if h3 != "":
		desk_text += " A second, older bundle is full of cross words about %s." % first(sim, h3)
		desk_sup.append(_sup("motive", h3, 1))
	_clue(c, "c_desk", "The desk", desk_text, scene, "desk", {"skill": "observation", "level": 2}, desk_sup)
	_clue(c, "c_phone", "The last call", "The phone's memory shows a call at %s from a number you don't recognise, and a scribbled reminder: 'come round after midnight, we'll talk'." % _time(hk - 1.5), scene, "phone", {"skill": "streetwise", "level": 2}, [_sup("time", "", 1)])
	_clue(c, "c_callrecord", "The exchange's call log", "The operator's log at the post office: the %s call to %s's line came from %s's home number." % [_time(hk - 1.5), vname, kname], "post_office", "records", {"skill": "streetwise", "level": 1}, [_sup("opportunity", k, 2)], {"needs": "c_phone"})
	# ---------------- the victim's last days: who they argued with, who they feared, what they stopped doing
	var tl: Array = []
	tl.append("%s: a loud row with %s about %s, overheard on the street." % [dayname(c, 3), kname, about_thing])
	tl.append("%s: told someone they were afraid of a visit, and would not say whose." % dayname(c, 4))
	var stopped: String = HOBBY_STOPPED.get(pv.hobby, "seeing people")
	var haunt: String = pv.haunts[0] if not pv.haunts.is_empty() else ""
	tl.append("%s: stopped %s%s, a habit of years." % [dayname(c, 5), stopped, (" at " + Brief.place_name(sim, haunt, "")) if haunt not in ["", pv.home] else ""])
	tl.append("From %s: the lamp stayed on all night and the door was bolted by dusk." % dayname(c, 6))
	var tl_sup := [_sup("motive", k, 1)]
	if h3 != "":
		tl.append("An older quarrel with %s, never settled." % first(sim, h3))
		tl_sup.append(_sup("motive", h3, 1))
	if h4 != "":
		tl.append("Twice that week %s was seen outside the house, watching." % first(sim, h4))
		tl_sup.append(_sup("motive", h4, 1))
	_clue(c, "c_timeline", "The last days", "%s's last days, from the diary, the calendar and the neighbours' memory:\n%s" % [vfirst, "\n".join(tl)], scene, "phone", {"skill": "empathy", "level": 2}, tl_sup)
	# ---------------- the weapon: in the open, or in the killer's home
	var public_site: bool = r.randf() < 0.55 or c["method"] == "poison"
	var wlot: String = pk.home
	if public_site:
		wlot = _pick(r, ["pageant_green", "marina", "launch_quay"])
	c["weapon_at"] = {"lot": wlot, "public": public_site}
	if public_site:
		_clue(c, "c_weapon", "The weapon", "Hidden under the reeds: %s. Wiped, but not well." % c["weapon"], wlot, "weapon", {"skill": "observation", "level": 3}, [_sup("means", k, 1)], {"tip": true})
	else:
		_clue(c, "c_weapon", "The weapon, at home", "At the back of %s's wardrobe: %s, still sticky. The search was worth it." % [kf, c["weapon"]], pk.home, "weapon", {"skill": "observation", "level": 2, "warrant": true}, [_sup("means", k, 3)])
	if public_site:
		var seers := neighbors(sim, wlot, 1, used)
		if not seers.is_empty():
			used.append(seers[0])
			_fact(c, "f_weapon_tip", "Late that night I saw %s by the %s, carrying something wrapped in a cloth." % [kname, Brief.place_name(sim, wlot, "")], "saw", [seers[0]], "free", [_sup("opportunity", k, 1)], k)
	# ---------------- at the killer's home (a warrant opens these)
	_clue(c, "c_k_shoes", "The boots in the hall", "In %s's hall: %s. The sole matches the prints exactly." % [kf, c["shoes"]], pk.home, "shoes", {"skill": "observation", "level": 2, "warrant": true}, [_sup("link", k, 3)], {"needs": "c_foot"})
	_clue(c, "c_k_coat", "The coat", "A dark coat, hastily washed. %s on the cuff, and a stain that didn't come out." % Prose.sentence(String(c["trace"])), pk.home, "coat", {"skill": "forensics", "level": 2, "warrant": true}, [_sup("link", k, 2)])
	# ---------------- records
	if m["buy"]:
		_clue(c, "c_receipt", "A purchase", "The ledger at %s: %s bought %s five days ago, paid cash." % [Brief.place_name(sim, m["shop"], ""), kname, c["weapon"]], m["shop"], "records", {"skill": "streetwise", "level": 1}, [_sup("means", k, 2)])
	else:
		var owners: Array = sim.order.filter(func(id): return id != k and id != v and id != c["found_by"] and sim.people[id].rel.has(k) and sim.alive(sim.people[id]))
		if not owners.is_empty():
			_fact(c, "f_owns", "%s keeps a whole set of those. The set on the mantel is one short. Funny, that." % kf, "owner", [owners[0]], "free", [_sup("means", k, 2)], k)
	# ---------------- the lab turns a dropped item into a name
	c["lab"] = {"c_dropped": {"text": "The lab: traces of %s on %s, and a smudge of skin oil. It was carried by someone who works with it every day." % [c["trace"], c["item"]], "supports": [_sup("link", k, 2)]}}
	# ---------------- testimony
	var args: Array = sim.order.filter(func(id): return id != k and id != v and sim.alive(sim.people[id]) and (sim.people[id].work == pk.work or sim.people[id].work == pv.work) and sim.people[id].work != "" and not used.has(id))
	if args.is_empty():
		args = neighbors(sim, pk.home, 3, used)
	var aw: Array = args.slice(0, 2)
	used.append_array(aw)
	_fact(c, "f_argument", "I saw %s and %s having a terrible row outside %s on %s. It was about %s." % [kname, vname, Brief.place_name(sim, pk.work if pk.work != "" else pk.home, ""), dayname(c, 3), about_thing], "victim", aw, "free", [_sup("motive", k, 2)], k)
	_fact(c, "f_trait_k", "%s? You couldn't miss them. %s, always." % [kname, Prose.sentence(c["trait"])], "suspects", sim.order.filter(func(id): return sim.people[id].rel.has(k) and id != k and not used.has(id)).slice(0, 3), "free", [], k)
	if not vn.is_empty():
		var wob := _witness_quality(sim, vn[0])
		var vt := _time(hk - 0.5 + wob["shift"])
		_fact(c, "f_vn_saw", "%sI was up with the cat. %s I saw somebody outside %s's: %s. Couldn't swear to who." % [wob["prefix"], ("About " + vt) if wob["shift"] == 0.0 else ("It was " + vt + ", or thereabouts,"), vfirst, c["trait"]], "saw", [vn[0]], "free", [_sup("opportunity", k, 1)], k)
		if wob["shift"] != 0.0:
			c["facts"]["f_vn_saw"]["unreliable"] = true
	if not kn.is_empty():
		var wob2 := _witness_quality(sim, kn[0])
		var s3 := 3 if wob2["shift"] == 0.0 else 2
		var t1 := _time(hk - 0.75 + wob2["shift"])
		var t2 := _time(hk + 0.8 + wob2["shift"])
		_fact(c, "f_kn_saw", "%sI couldn't sleep. I saw %s go out at about %s and come back at about %s. Didn't think anything of it, until now." % [wob2["prefix"], kname, t1, t2], "saw", [kn[0]], "free", [_sup("opportunity", k, s3)], k)
		if wob2["shift"] != 0.0:
			c["facts"]["f_kn_saw"]["unreliable"] = true
		_fact(c, "f_lead_kn", "If you want to know who goes where at night on this street, ask %s. Never sleeps." % first(sim, kn[0]), "suspects", sim.order.filter(func(id): return sim.people[id].home == pk.home and id != k and id != v and sim.alive(sim.people[id])).slice(0, 1) + neighbors(sim, pk.home, 1, [kn[0], k, v]), "free", [], k)
	var ow: Array = sim.order.filter(func(id): return sim.people[id].rel.has(k) and id != k and id != v and id != c["found_by"] and sim.alive(sim.people[id])).slice(0, 2)
	_fact(c, "f_owner", "That's %s's. I'd know it anywhere." % kname, "owner", ow, "free", [_sup("link", k, 2)], k)
	c["owner_item_knowers"] = ow
	# a confidant who knows the real reason (rapport needed)
	var confidants: Array = sim.order.filter(func(id): return pv.affinity(id) >= 25.0 and id != k and sim.alive(sim.people[id]) and not used.has(id))
	if not confidants.is_empty():
		_fact(c, "f_confidant", "%s told me last week it was coming to a head, all of it about %s. They were frightened of %s." % [vfirst, thing_about(c["motive_thing"]), kf], "victim", [confidants[0]], "rapport", [_sup("motive", k, 2)], k)
	# ---------------- red herrings
	if h1 != "":
		var prof: Dictionary = c["profiles"][h1]
		var seer_lot: String = prof["secret_lot"]
		var seers2 := neighbors(sim, seer_lot, 1, used)
		if not seers2.is_empty():
			used.append(seers2[0])
			_fact(c, "f_h1_seen", "Past midnight I saw %s near %s. Looked like they didn't want to be seen." % [name_of(sim, h1), Brief.place_name(sim, seer_lot, "")], "saw", [seers2[0]], "free", [], h1)
		_fact(c, "f_h1_secret", "All right. %s (confessing): %s. I lied because %s. I had nothing to do with %s." % [first(sim, h1), prof["secret_text"], prof["secret_why"], vname], "secret", [h1], "pressure", [], h1)
		_fact(c, "f_h1_confirm", "Yes. %s was with me, or in my sight, from before midnight until nearly four. Please keep it quiet." % first(sim, h1), "alibi", [prof["confirmer"]], "pressure", [_sup("exonerate", h1, 3)], h1)
		c["facts"]["f_h1_secret"]["needs"] = ["f_h1_seen"]
		c["facts"]["f_h1_confirm"]["needs"] = ["f_h1_secret"]
		if prof.get("cult", false):
			for fid in ["f_h1_seen", "f_h1_secret", "f_h1_confirm"]:
				if c["facts"].has(fid):
					c["facts"][fid]["cult"] = true
	if h2 != "":
		var prof2: Dictionary = c["profiles"][h2]
		_fact(c, "f_h2_confirm", "Yes, %s was %s the whole night. I saw them there at one, and again at three." % [first(sim, h2), cb["alibi_places"][prof2["alibi_lot"]]], "alibi", [prof2["confirmer"]], "free", [_sup("exonerate", h2, 3)], h2)
	if h3 != "":
		_fact(c, "f_h3_motive", "%s had their own reasons. They fell out with %s last year. But %s? No. Not a violent bone in them." % [name_of(sim, h3), vfirst, first(sim, h3)], "victim", sim.order.filter(func(id): return sim.people[id].rel.has(h3) and id != h3 and id != v and not used.has(id)).slice(0, 1), "free", [_sup("motive", h3, 1)], h3)
		_fact(c, "f_h3_evening", "%s called round at about eight and left before nine, smiling. The victim was alive and well at nine, so the time of death rules them out." % first(sim, h3), "saw", [vn[1] if vn.size() > 1 else c["found_by"]], "free", [_sup("exonerate", h3, 1)], h3)
	if h4 != "":
		var prof4: Dictionary = c["profiles"][h4]
		var h4n := first(sim, h4)
		var h4_ow: Array = sim.order.filter(func(id): return sim.people[id].rel.has(h4) and id != h4 and id != v and id != k and not used.has(id)).slice(0, 1)
		_fact(c, "f_h4_motive", "%s and %s were barely speaking. %s had a real reason to want %s gone. Everybody on the street knew." % [h4n, vfirst, h4n, vfirst], "victim", h4_ow if not h4_ow.is_empty() else [c["found_by"]], "free", [_sup("motive", h4, 2)], h4)
		var h4_means: Array = sim.order.filter(func(id): return sim.people[id].rel.has(h4) and id != h4 and id != v and id != k and not used.has(id) and not h4_ow.has(id)).slice(0, 1)
		_fact(c, "f_h4_means", "%s keeps %s in the shed. I've seen it. If it's missing, ask %s." % [h4n, "one of those" if c["method"] != "poison" else "the same stuff", h4n], "owner", h4_means if not h4_means.is_empty() else [c["found_by"]], "free", [_sup("means", h4, 2)], h4)
		var seen4 := neighbors(sim, scene, 3, used + [h4])
		_fact(c, "f_h4_seen", "I saw %s walking up toward %s's place in the early evening, with a face like a shut door." % [h4n, vfirst], "saw", [seen4[0]] if not seen4.is_empty() else [c["found_by"]], "free", [_sup("opportunity", h4, 1)], h4)
		_fact(c, "f_h4_clear", "%s was at my kitchen table from nine until past two, drafting a letter they didn't send. I had to put them to bed on the sofa. They couldn't have gone anywhere." % h4n, "alibi", [prof4["confirmer"]], "pressure", [_sup("exonerate", h4, 3)], h4)
		c["facts"]["f_h4_clear"]["needs"] = ["f_h4_seen"]


## A witness is not always a good one: old, tired or fond of a drink, they get the hour wrong and say so with less certainty.
static func _witness_quality(sim: RefCounted, id: String) -> Dictionary:
	var p: RefCounted = sim.people[id]
	var shaky: bool = p.age >= 76 or (p.trait_of("honest") < 0.3 and p.trait_of("sociable") > 0.6) or absi(hash("wit|" + id)) % 100 < 14
	if not shaky:
		return {"shift": 0.0, "prefix": ""}
	var sgn := -1.0 if absi(hash("sh|" + id)) % 2 == 0 else 1.0
	var prefixes := ["Now, I'd had a drop, so mind. ", "My eyes aren't what they were, and my watch runs slow. ", "It's all a bit of a blur now. ", "I might be mixing it with the night before. "]
	return {"shift": sgn * 0.6, "prefix": prefixes[absi(hash("pf|" + id)) % prefixes.size()]}


## The person who comes into view later: seen at the victim's door earlier in the week, with their own reason and their own cover.
static func _shadow(sim: RefCounted, c: Dictionary, cb: Dictionary, r: RandomNumberGenerator, sid: String, used: Array) -> void:
	var v: String = c["victim"]
	var vfirst := first(sim, v)
	var sn := first(sim, sid)
	var hk: float = c["hour"]
	var confirm := neighbors(sim, sim.people[sid].home, 2, used + [sid])
	c["profiles"][sid] = {"role": "shadow", "alibi": "shadow", "claim": "", "claim_kind": "claim_weak", "lie": false, "alibi_lot": sim.people[sid].home,
		"night": {"lot": sim.people[sid].home, "from": hk - 1.0, "to": hk + 1.0}, "tell": "polite, too polite", "id": sid,
		"confirmer": confirm[0] if not confirm.is_empty() else c["found_by"]}
	c["profiles"][sid]["claim"] = String(load("res://scripts/detective/voice.gd").say("claim_weak", sim, c, sid, {}))
	var watchers := neighbors(sim, c["scene"], 4, used + [sid])
	var w1: String = watchers[0] if not watchers.is_empty() else c["found_by"]
	_clue(c, "c_shadow", "A note in another hand", "Tucked into the appointment book, a note that isn't %s's: 'Thursday again. Bring what we agreed or I tell them all.' It is signed with a single initial, %s." % [vfirst, sn.substr(0, 1)], c["scene"], "phone", {"skill": "observation", "level": 2}, [_sup("motive", sid, 1)], {"reveals": sid})
	_fact(c, "f_shadow_seen", "That's not all of it. %s was at %s's door twice that week. Late, and not to borrow sugar. %s didn't want it known." % [name_of(sim, sid), vfirst, sn], "victim", [w1], "free", [_sup("motive", sid, 1), _sup("opportunity", sid, 1)], sid)
	c["facts"]["f_shadow_seen"]["reveals"] = sid
	_fact(c, "f_shadow_clear", "%s was here with me until past one, helping with the boiler. I walked them home myself. They couldn't have been at %s's." % [sn, vfirst], "alibi", [c["profiles"][sid]["confirmer"]], "pressure", [_sup("exonerate", sid, 3)], sid)
	c["facts"]["f_shadow_clear"]["needs"] = ["f_shadow_seen"]
	c["hidden"] = {"id": sid, "triggers": ["c_shadow", "f_shadow_seen"]}
	c["relatives"][sid] = relatives_of(sim, sid)


## The ways a detective can be led astray: a planted object, a witness who lies for her own reasons, a doorbell camera whose clock is far out.
static func _misdirection(sim: RefCounted, c: Dictionary, cb: Dictionary, r: RandomNumberGenerator, used: Array) -> void:
	var k: String = c["killer"]
	var framed := ""
	for key in ["weak", "shaky", "secret"]:
		for sid in c["suspects"]:
			if c["profiles"][sid].get("alibi", "") == key and framed == "":
				framed = sid
	if framed == "":
		return
	c["framed"] = framed
	var fn := first(sim, framed)
	if r.randf() < 0.5:
		var items := ["a woollen hat", "a work glove", "a scarf with initials stitched in the corner", "a cigarette case"]
		var it: String = items[r.randi() % items.size()]
		_clue(c, "c_planted", "Left on the gate", "Caught on the gatepost: %s that half the street would swear is %s's." % [it, fn], c["scene"], "garden", {"skill": "observation", "level": 2}, [_sup("link", framed, 2)], {"lab": true, "planted": true})
		c["lab"]["c_planted"] = {"text": "The lab: no dust on it, though everything round it was dusty. It is dry; the ground was wet. It was put there after the weather turned, by someone with gloves on. Whoever left it wanted it found. Planted.", "supports": [_sup("exonerate", framed, 2)]}
	if r.randf() < 0.55:
		var pool := neighbors(sim, c["scene"], 10, used + [framed])
		pool = pool.filter(func(id): return sim.people[id].trait_of("honest") < 0.55)
		if not pool.is_empty():
			var liar: String = pool[0]
			used.append(liar)
			var ln := first(sim, liar)
			c["liar"] = liar
			_fact(c, "f_liar_saw", "I'll say it plain: I saw %s going in at about %s. Walking quick, head down. I'd know that walk anywhere." % [name_of(sim, framed), _time(float(c["hour"]) - 0.4)], "saw", [liar], "free", [_sup("opportunity", framed, 2)], framed)
			c["facts"]["f_liar_saw"]["false"] = true
			var deb := neighbors(sim, sim.people[liar].home, 2, used + [liar])
			if not deb.is_empty():
				used.append(deb[0])
				_fact(c, "f_liar_exposed", "%s? They've had it in for %s ever since the business with the allotment. I wouldn't believe a word. And that night %s was at the %s with me, not on any street." % [ln, fn, ln, "Low Water" if r.randf() < 0.5 else "Pink Heron"], "suspects", [deb[0]], "pressure", [_sup("exonerate", framed, 2)], framed)
				c["facts"]["f_liar_exposed"]["needs"] = ["f_liar_saw"]


# =========================================================================== surprises
## Has anything the detective now knows brought a new name into view? Returns the id of the newly visible suspect, or "".
static func emerge(sim: RefCounted, c: Dictionary, det: RefCounted) -> String:
	var h: Dictionary = c.get("hidden", {})
	if h.is_empty() or c["suspects"].has(h["id"]):
		return ""
	for t in h["triggers"]:
		if det.has(t):
			c["suspects"].append(h["id"])
			c["emerged"] = h["id"]
			return h["id"]
	return ""


# =========================================================================== applying the past
## Write the recent past into the sim: the grudge, the rumour, who fell out with whom. Done before the player ever looks.
static func apply_backstory(sim: RefCounted, c: Dictionary) -> void:
	var k: String = c["killer"]
	var v: String = c["victim"]
	var pk: RefCounted = sim.people[k]
	var pv: RefCounted = sim.people[v]
	var strength: float = {"grudge": -55.0, "money": -45.0, "family": -35.0, "silence": -25.0, "passion": -30.0}[c["motive"]]
	pk.rel[v] = {"affinity": strength, "trust": -30.0}
	pv.rel[k] = {"affinity": strength * 0.9, "trust": -35.0}
	pk.remember(c["day"] - 2, v, "the row about %s" % thing_about(c["motive_thing"]), 1.0)
	pv.remember(c["day"] - 2, k, "the row about %s" % thing_about(c["motive_thing"]), 1.0)
	for sid in c["suspects"]:
		if sid != k:
			var ps: RefCounted = sim.people[sid]
			if c["profiles"][sid]["alibi"] == "weak":
				ps.rel[v] = {"affinity": -20.0, "trust": -10.0}
	sim.seed_rumor(k, "%s and %s are at each other's throats." % [pk.display, pv.display], true, v, 2, 70.0)


# =========================================================================== the night
## Called when the day ends: the murder, and what everyone really did. Writes the night record and kills the victim.
static func execute(sim: RefCounted, c: Dictionary) -> void:
	var d: int = c["day"]
	var night: Dictionary = sim.night.get(d, {})
	for id in c["profiles"]:
		var pr: Dictionary = c["profiles"][id]
		night[id] = {"lot": pr["night"]["lot"], "from": float(pr["night"]["from"]), "to": float(pr["night"]["to"])}
	night[c["victim"]] = {"lot": c["scene"], "from": 24.0, "to": 30.0}
	sim.night[d] = night
	var pv: RefCounted = sim.people[c["victim"]]
	pv.dead = true
	pv.location = c["scene"]
	sim.log_event("murder", c["victim"], "%s was found dead at %s." % [pv.display, Brief.place_name(sim, c["scene"], "")])
	c["status"] = "open"


static func discovery_time(c: Dictionary) -> String:
	return _time(c["found_hour"])


static func discovery_text(sim: RefCounted, c: Dictionary) -> String:
	var f: String = c["found_by"]
	return Prose.clean("%s, %s's %s, found %s dead at %s at about %s this morning. The Sheriff has asked you to take the case." % [name_of(sim, f), first(sim, c["victim"]), c.get("found_rel", "neighbour"), name_of(sim, c["victim"]), Brief.place_name(sim, c["scene"], ""), _time(c["found_hour"])])


# --------------------------------------------------------------------------- cameras, prints, families
static func relatives_of(sim: RefCounted, id: String) -> Array:
	var p: RefCounted = sim.people[id]
	var out: Array = []
	for oid in sim.order:
		var o: RefCounted = sim.people[oid]
		if oid == id or not sim.alive(o) or o.age < 18:
			continue
		if o.home == p.home or p.affinity(oid) >= 70.0:
			out.append(oid)
	return out.slice(0, 3)


## Most doorbell clocks are a few minutes out. Now and then one has not been set since the power cut, and shows the night an hour wrong.
static func _cam_offset(r: RandomNumberGenerator) -> int:
	if r.randf() < 0.3:
		return (1 if r.randf() < 0.5 else -1) * r.randi_range(28, 70)
	return r.randi_range(-12, 12)


static func _cameras_prints_family(sim: RefCounted, c: Dictionary, r: RandomNumberGenerator, vn: Array, kn: Array) -> void:
	var k: String = c["killer"]
	var v: String = c["victim"]
	# doorbell cameras: one by the killer's street, one by the victim's
	var cams: Array = []
	if not kn.is_empty():
		cams.append({"id": "cam_door_" + kn[0], "lot": sim.people[kn[0]].home, "label": "%s's doorbell camera" % name_of(sim, kn[0]), "quality": "low", "radius": 48.0, "offset": _cam_offset(r), "owner": kn[0], "kind": "doorbell"})
	if not vn.is_empty():
		cams.append({"id": "cam_door_" + vn[0], "lot": sim.people[vn[0]].home, "label": "%s's doorbell camera" % name_of(sim, vn[0]), "quality": "low", "radius": 48.0, "offset": _cam_offset(r), "owner": vn[0], "kind": "doorbell"})
	c["cameras"] = cams
	# latent prints: who touched what. Gloves leave nothing of the killer's.
	var lat: Array = []
	var n := 0
	var sus: Array = c["suspects"]
	var lookalike := ""
	for sid in sus:
		if c["profiles"][sid].get("alibi", "") == "secret":
			lookalike = sid
	c["lookalike"] = lookalike
	var add := func(spot: String, owner: String, q: int) -> void:
		lat.append({"id": "lp%d" % lat.size(), "spot": spot, "owner": owner, "quality": q})
	add.call("door", v, 78)
	add.call("door", c["found_by"], 66)
	add.call("phone", v, 80)
	add.call("desk", v, 85)
	add.call("garden", "unknown", 20)
	if not c["gloves"]:
		add.call("door", k, 62)
		add.call("phone", k, 48)        # a partial: not good enough to be sure
		add.call("floor", k, 72)
	for sid in sus:
		if c["profiles"][sid].get("alibi", "") == "weak":
			add.call("desk", sid, 70)   # the 8pm visit: a cup on the desk
	c["latents"] = lat
	# families: who would cover for whom
	var rel: Dictionary = {}
	for sid in sus:
		rel[sid] = relatives_of(sim, sid)
	c["relatives"] = rel
