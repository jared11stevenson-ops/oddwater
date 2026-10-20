extends RefCounted
## The case engine. It reads the living town, picks a victim and a killer whose real relationship makes a motive plausible,
## writes the recent past into the sim (arguments, rumours, grudges), decides the night, and builds the web of clues, witnesses
## and lies that lets a player work it out. Everything is deterministic for a seed. A case is a dictionary (the truth).

const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Relationship = preload("res://scripts/sim/relationship.gd")

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


static func _rng(seed_v: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%s" % [seed_v, salt])
	return r


static func _pick(r: RandomNumberGenerator, a: Array) -> Variant:
	return a[r.randi() % a.size()]


static func name_of(sim: RefCounted, id: String) -> String:
	return sim.people[id].display if sim.people.has(id) else id


static func first(sim: RefCounted, id: String) -> String:
	return String(name_of(sim, id)).split(" ")[0]


static func _adults(sim: RefCounted) -> Array:
	return sim.order.filter(func(id):
		var p: RefCounted = sim.people[id]
		return id != "player" and sim.alive(p) and p.group in ["adult", "elder"] and p.age >= 25 and p.home != "")


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
static func generate(sim: RefCounted, seed_v: int, day: int) -> Dictionary:
	var cb: Dictionary = Data.load_json("detective/casebook.json")
	var r := _rng(seed_v, "case%d" % day)
	var adults := _adults(sim)
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
	var motive: String = pair["type"]
	if r.randf() < 0.3 and motive != "family":
		motive = "silence"
	elif motive == "grudge" and r.randf() < 0.3:
		motive = "passion"
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
	var method: String = _pick(r, methods)
	var m: Dictionary = cb["methods"][method]
	var weapon: String = _pick(r, m["weapons"])
	var thing: String = _pick(r, cb["motives"][motive]["things"])
	var trait_k: String = _pick(r, cb["traits"])
	var item: String = _pick(r, cb["dropped"])
	var shoes: String = _pick(r, cb["shoes"])
	var c := {"id": "case_%d" % day, "day": day, "seed": seed_v, "victim": victim, "killer": killer, "motive": motive, "motive_thing": thing,
		"method": method, "weapon": weapon, "scene": scene, "scene_kind": scene_kind, "hour": hour, "trait": trait_k, "item": item, "shoes": shoes,
		"trace": trace_for(pk.job), "facts": {}, "clues": {}, "profiles": {}, "suspects": [], "keyholders": [], "weapon_at": {}, "status": "planned"}
	# ---- the cast around the crime
	var used: Array = [victim, killer]
	var finder := ""
	if scene_kind == "work":
		for id in sim.order:
			if id != victim and sim.alive(sim.people[id]) and sim.people[id].work == scene and not used.has(id):
				finder = id
				break
	if finder == "":
		var hm: Array = housemates
		var nb: Array = neighbors(sim, scene, 1, used)
		finder = hm[0] if not hm.is_empty() else (nb[0] if not nb.is_empty() else "")
	used.append(finder)
	c["found_by"] = finder
	c["found_hour"] = 6.5 + r.randf() * 0.8
	var vn: Array = neighbors(sim, scene, 2, used)
	used.append_array(vn)
	var kn: Array = neighbors(sim, pk.home, 2, used)
	used.append_array(kn)
	# red herrings: three people with their own reasons to be suspicious
	var herrings: Array = []
	var rel_ids: Array = []
	for id in pv.rel:
		if adults.has(id) and not used.has(id):
			rel_ids.append(id)
	rel_ids.sort_custom(func(a, b): return pv.affinity(a) < pv.affinity(b))
	for id in rel_ids:
		if herrings.size() < 3:
			herrings.append(id)
	while herrings.size() < 3:
		var cand: String = _pick(r, adults)
		if not used.has(cand) and not herrings.has(cand):
			herrings.append(cand)
	used.append_array(herrings)
	c["suspects"] = [killer] + herrings
	# ---- the suspects' real nights, and what they will say
	_profiles(sim, c, cb, r, herrings, used)
	_facts_and_clues(sim, c, cb, r, vn, kn, used)
	return c


# --------------------------------------------------------------------------- profiles
static func _profiles(sim: RefCounted, c: Dictionary, cb: Dictionary, r: RandomNumberGenerator, herrings: Array, used: Array) -> void:
	var killer: String = c["killer"]
	var victim: String = c["victim"]
	var hk: float = c["hour"]
	c["profiles"][killer] = {"role": "killer", "alibi": "false", "claim": "I was in bed by ten. Alone, before you ask. I didn't hear a thing.", "lie": true,
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
		"secret_why": sec["why"], "claim": "I was home asleep. Nothing to tell. I'm not hiding anything.", "lie": true, "partner": partner, "secret_lot": secret_lot,
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
	c["profiles"][h2] = {"role": "herring", "alibi": "verified", "claim": "I was %s, all night. Ask anyone there." % cb["alibi_places"][al], "lie": false, "alibi_lot": al,
		"confirmer": confirmer2, "night": {"lot": al, "from": hk - 3.0, "to": hk + 2.0}, "tell": "calm, a little offended"}
	# red herring 3: no alibi, a petty reason, and nothing else
	var h3: String = herrings[2]
	c["profiles"][h3] = {"role": "herring", "alibi": "weak", "claim": "I was at home. On my own. I know how that sounds.", "lie": false, "night": {"lot": sim.people[h3].home, "from": hk - 1.0, "to": hk + 1.0}, "tell": "defensive, but honest"}
	for id in c["profiles"]:
		c["profiles"][id]["id"] = id


# --------------------------------------------------------------------------- facts and clues
static func _fact(c: Dictionary, id: String, text: String, topic: String, knowers: Array, reveal: String, supports: Array, about: String = "") -> void:
	c["facts"][id] = {"id": id, "text": text, "topic": topic, "knowers": knowers, "reveal": reveal, "supports": supports, "about": about}


static func _clue(c: Dictionary, id: String, title: String, text: String, lot: String, spot: String, gate: Dictionary, supports: Array, extra: Dictionary = {}) -> void:
	var d := {"id": id, "title": title, "text": text, "lot": lot, "spot": spot, "gate": gate, "supports": supports}
	d.merge(extra, true)
	c["clues"][id] = d


static func _sup(cat: String, about: String, strength: int) -> Dictionary:
	return {"cat": cat, "about": about, "strength": strength}


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
	for id in c["suspects"]:
		if c["profiles"][id].get("alibi", "") == "secret":
			h1 = id
		elif c["profiles"][id].get("alibi", "") == "verified":
			h2 = id
		elif c["profiles"][id].get("alibi", "") == "weak":
			h3 = id
	# ---------------- the physical scene
	_clue(c, "c_body", "The body", "%s lies where they fell. %s. They have been dead some hours." % [vname, String(m["wound"]).capitalize()], scene, "body", {"skill": "forensics", "level": 1}, [_sup("method", c["method"], 3)])
	_clue(c, "c_time", "Time of death", "Body temperature and stiffness put the death between %s and %s." % [_time(hk - 1.0), _time(hk + 1.0)], scene, "body", {"skill": "forensics", "level": 2}, [_sup("time", "", 2)])
	var keyholders := [v, k]
	if not c["found_by"] in keyholders:
		keyholders.append(c["found_by"])
	c["keyholders"] = keyholders
	_clue(c, "c_door", "No forced entry", "The locks are intact. Whoever came in was let in, or had a key. Keys are held by %s." % ", ".join(keyholders.map(func(x): return name_of(sim, x))), scene, "door", {"skill": "observation", "level": 2}, keyholders.map(func(x): return _sup("opportunity", x, 1)))
	_clue(c, "c_dropped", "Something dropped", "Under the edge of the rug: %s. It doesn't belong to the house." % c["item"], scene, "floor", {"skill": "observation", "level": 2}, [_sup("link", k, 1)], {"lab": true})
	_clue(c, "c_foot", "Footprints in the soft ground", "A clear print by the path: %s. Someone stood here a while." % c["shoes"], scene, "garden", {"skill": "observation", "level": 2}, [])
	var desk_text := ""
	match c["motive"]:
		"grudge": desk_text = "A drawer of drafts: angry letters to %s about %s. None sent. One says 'I'll make you sorry'." % [kname, c["motive_thing"]]
		"money": desk_text = "An IOU signed by %s, and a note to self: 'Call %s's bluff Friday. Or the sheriff.' Concerning %s." % [kname, first(sim, k), c["motive_thing"]]
		"family": desk_text = "A solicitor's draft: %s. %s is named in the old will and struck from the new one." % [c["motive_thing"], kname]
		"silence": desk_text = "Notes in a hand that shakes: '%s. I have to say something. I'll tell %s first.'" % [c["motive_thing"], first(sim, k)]
		"passion": desk_text = "A half-written letter: '%s. I'm sorry to do it like this, %s.'" % [c["motive_thing"], first(sim, k)]
	var desk_sup := [_sup("motive", k, 1)]
	if h3 != "":
		desk_text += " A second, older bundle is full of cross words about %s." % first(sim, h3)
		desk_sup.append(_sup("motive", h3, 1))
	_clue(c, "c_desk", "The desk", desk_text, scene, "desk", {"skill": "observation", "level": 2}, desk_sup)
	_clue(c, "c_phone", "The last call", "The phone's memory shows a call at %s from a number you don't recognise, and a scribbled reminder: 'come round after midnight, we'll talk'." % _time(hk - 1.5), scene, "phone", {"skill": "streetwise", "level": 2}, [_sup("time", "", 1)])
	_clue(c, "c_callrecord", "The exchange's call log", "The operator's log at the post office: the %s call to %s's line came from %s's home number." % [_time(hk - 1.5), vname, kname], "post_office", "records", {"skill": "streetwise", "level": 1}, [_sup("opportunity", k, 2)], {"needs": "c_phone"})
	# ---------------- the weapon: in the open, or in the killer's home
	var public_site: bool = r.randf() < 0.55 or c["method"] == "poison"
	var wlot: String = pk.home
	if public_site:
		wlot = _pick(r, ["pageant_green", "marina", "launch_quay"])
	c["weapon_at"] = {"lot": wlot, "public": public_site}
	if public_site:
		_clue(c, "c_weapon", "The weapon", "Hidden under the reeds: %s. Wiped, but not well." % c["weapon"], wlot, "weapon", {"skill": "observation", "level": 3}, [_sup("means", k, 1)], {"tip": true})
	else:
		_clue(c, "c_weapon", "The weapon, at home", "At the back of %s's wardrobe: %s, still sticky. The search was worth it." % [first(sim, k), c["weapon"]], pk.home, "weapon", {"skill": "observation", "level": 2, "warrant": true}, [_sup("means", k, 3)])
	if public_site:
		var seers := neighbors(sim, wlot, 1, used)
		if not seers.is_empty():
			used.append(seers[0])
			_fact(c, "f_weapon_tip", "Late that night I saw %s by the %s, carrying something wrapped in a cloth." % [kname, Brief.place_name(sim, wlot, "")], "saw", [seers[0]], "free", [_sup("opportunity", k, 1)], k)
	# ---------------- at the killer's home (a warrant opens these)
	_clue(c, "c_k_shoes", "The boots in the hall", "In %s's hall: %s. The sole matches the prints exactly." % [first(sim, k), c["shoes"]], pk.home, "shoes", {"skill": "observation", "level": 2, "warrant": true}, [_sup("link", k, 3)], {"needs": "c_foot"})
	_clue(c, "c_k_coat", "The coat", "A dark coat, hastily washed. %s on the cuff, and a stain that didn't come out." % String(c["trace"]).capitalize(), pk.home, "coat", {"skill": "forensics", "level": 2, "warrant": true}, [_sup("link", k, 2)])
	# ---------------- records
	if m["buy"]:
		_clue(c, "c_receipt", "A purchase", "The ledger at %s: %s bought %s five days ago, paid cash." % [Brief.place_name(sim, m["shop"], ""), kname, c["weapon"]], m["shop"], "records", {"skill": "streetwise", "level": 1}, [_sup("means", k, 2)])
	else:
		var owners: Array = sim.order.filter(func(id): return id != k and id != v and sim.people[id].rel.has(k) and sim.alive(sim.people[id]))
		if not owners.is_empty():
			_fact(c, "f_owns", "%s keeps a whole set of those. The set on the mantel is one short. Funny, that." % first(sim, k), "owner", [owners[0]], "free", [_sup("means", k, 2)], k)
	# ---------------- the lab turns a dropped item into a name
	c["lab"] = {"c_dropped": {"text": "The lab: traces of %s on %s, and a smudge of skin oil. It was carried by someone who works with it every day." % [c["trace"], c["item"]], "supports": [_sup("link", k, 2)]}}
	# ---------------- testimony
	var args: Array = sim.order.filter(func(id): return id != k and id != v and sim.alive(sim.people[id]) and (sim.people[id].work == pk.work or sim.people[id].work == pv.work) and sim.people[id].work != "" and not used.has(id))
	if args.is_empty():
		args = neighbors(sim, pk.home, 3, used)
	var aw: Array = args.slice(0, 2)
	used.append_array(aw)
	_fact(c, "f_argument", "I saw %s and %s having a terrible row outside %s on %s. It was about %s." % [kname, vname, Brief.place_name(sim, pk.work if pk.work != "" else pk.home, ""), DAYS[(int(c["day"]) + 3) % 7], c["motive_thing"]], "victim", aw, "free", [_sup("motive", k, 2)], k)
	_fact(c, "f_trait_k", "%s? You couldn't miss them. %s, always." % [kname, c["trait"].capitalize()], "suspects", sim.order.filter(func(id): return sim.people[id].rel.has(k) and id != k and not used.has(id)).slice(0, 3), "free", [], k)
	if not vn.is_empty():
		_fact(c, "f_vn_saw", "I was up with the cat. About %s I saw somebody outside %s's: %s. Couldn't swear to who." % [_time(hk - 0.5), first(sim, v), c["trait"]], "saw", [vn[0]], "free", [_sup("opportunity", k, 1)], k)
	if not kn.is_empty():
		_fact(c, "f_kn_saw", "I couldn't sleep. I saw %s go out at about %s and come back at about %s. Didn't think anything of it, until now." % [kname, _time(hk - 0.75), _time(hk + 0.8)], "saw", [kn[0]], "free", [_sup("opportunity", k, 3)], k)
		_fact(c, "f_lead_kn", "If you want to know who goes where at night on this street, ask %s. Never sleeps." % first(sim, kn[0]), "suspects", sim.order.filter(func(id): return sim.people[id].home == pk.home and id != k and id != v and sim.alive(sim.people[id])).slice(0, 1) + neighbors(sim, pk.home, 1, [kn[0], k, v]), "free", [], k)
	var ow: Array = sim.order.filter(func(id): return sim.people[id].rel.has(k) and id != k and id != v and sim.alive(sim.people[id])).slice(0, 2)
	_fact(c, "f_owner", "That's %s's. I'd know it anywhere." % kname, "owner", ow, "free", [_sup("link", k, 2)], k)
	c["owner_item_knowers"] = ow
	# a confidant who knows the real reason (rapport needed)
	var confidants: Array = sim.order.filter(func(id): return pv.affinity(id) >= 25.0 and id != k and sim.alive(sim.people[id]) and not used.has(id))
	if not confidants.is_empty():
		_fact(c, "f_confidant", "%s told me last week it was coming to a head. %s. They were frightened of %s." % [first(sim, v), c["motive_thing"].capitalize(), first(sim, k)], "victim", [confidants[0]], "rapport", [_sup("motive", k, 2)], k)
	# ---------------- red herrings
	if h1 != "":
		var prof: Dictionary = c["profiles"][h1]
		var seer_lot: String = prof["secret_lot"]
		var seers2 := neighbors(sim, seer_lot, 1, used)
		if not seers2.is_empty():
			used.append(seers2[0])
			_fact(c, "f_h1_seen", "Past midnight I saw %s near %s. Looked like they didn't want to be seen." % [name_of(sim, h1), Brief.place_name(sim, seer_lot, "")], "saw", [seers2[0]], "free", [], h1)
		_fact(c, "f_h1_secret", "All right. %s %s. I lied because %s. I had nothing to do with %s." % [first(sim, h1) + " " + "(confessing):", prof["secret_text"], prof["secret_why"], vname], "secret", [h1], "pressure", [], h1)
		_fact(c, "f_h1_confirm", "Yes. %s was with me, or in my sight, from before midnight until nearly four. Please keep it quiet." % first(sim, h1), "alibi", [prof["confirmer"]], "pressure", [_sup("exonerate", h1, 3)], h1)
		c["facts"]["f_h1_secret"]["needs"] = ["f_h1_seen"]
		c["facts"]["f_h1_confirm"]["needs"] = ["f_h1_secret"]
	if h2 != "":
		var prof2: Dictionary = c["profiles"][h2]
		_fact(c, "f_h2_confirm", "Yes, %s was %s the whole night. I saw them there at one, and again at three." % [first(sim, h2), cb["alibi_places"][prof2["alibi_lot"]]], "alibi", [prof2["confirmer"]], "free", [_sup("exonerate", h2, 3)], h2)
	if h3 != "":
		_fact(c, "f_h3_motive", "%s had their own reasons. They fell out with %s last year. But %s? No. Not a violent bone in them." % [name_of(sim, h3), first(sim, v), first(sim, h3)], "victim", sim.order.filter(func(id): return sim.people[id].rel.has(h3) and id != h3 and id != v and not used.has(id)).slice(0, 1), "free", [_sup("motive", h3, 1)], h3)
		_fact(c, "f_h3_evening", "%s called round at about eight and left before nine, smiling. The victim was alive and well at nine, so the time of death rules them out." % first(sim, h3), "saw", [vn[1] if vn.size() > 1 else c["found_by"]], "free", [_sup("exonerate", h3, 1)], h3)


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
	pk.remember(c["day"] - 2, v, "the row about %s" % c["motive_thing"], 1.0)
	pv.remember(c["day"] - 2, k, "the row about %s" % c["motive_thing"], 1.0)
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


static func discovery_text(sim: RefCounted, c: Dictionary) -> String:
	var f: String = c["found_by"]
	return "%s found %s dead at %s at about %s this morning. The Sheriff has asked you to take the case." % [name_of(sim, f), name_of(sim, c["victim"]), Brief.place_name(sim, c["scene"], ""), _time(c["found_hour"])]
