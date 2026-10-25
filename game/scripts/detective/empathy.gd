extends RefCounted
## Empathy. The dead were people. A "Who they were" dossier is built from what the living tell you (their days, who they loved, a small
## kindness, what they were planning), each row a claim in the notebook. Telling a family member or a friend is a scene whose words vary
## with their tie to the dead and with how you do it: sit with them first and they may give you what they would not give an inquiry. You
## carry one small thing of the victim's, and at the end you take it back to the family.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")

const ORDER := ["routine", "kindness", "loved", "planning"]
const GATED := ["loved", "planning"]
const TIES := ["spouse", "child", "parent", "sibling", "friend", "colleague", "neighbour"]


static func _d() -> Dictionary:
	return Prose.json("detective/empathy.json")


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


## How this person stood to the dead: spouse, child, parent, sibling, friend, colleague or neighbour ("" if no tie at all).
static func relation(g: RefCounted, victim: String, other: String) -> String:
	var sim: RefCounted = g.sim
	if not sim.people.has(victim) or not sim.people.has(other) or victim == other:
		return ""
	var a: RefCounted = sim.people[victim]
	var b: RefCounted = sim.people[other]
	if a.home != "" and a.home == b.home:
		var gap: int = absi(int(a.age) - int(b.age))
		if gap >= 16:
			return "parent" if int(b.age) > int(a.age) else "child"
		return "sibling" if absi(hash("%s|%s|rel" % [victim, other])) % 4 == 0 else "spouse"
	if a.work != "" and a.work == b.work:
		return "colleague"
	if b.affinity(victim) >= 22.0 or a.affinity(other) >= 22.0:
		return "friend"
	if g.distance(a.home, b.home) < 140.0 and (b.rel.has(victim) or a.rel.has(other)):
		return "neighbour"
	return ""


## The people the dead were close to, closest first. The killer is left out: who they loved is what the town knows of them, not a clue.
static func circle(g: RefCounted) -> Array:
	var sim: RefCounted = g.sim
	var v: String = String(g.case.get("victim", ""))
	if not sim.people.has(v):
		return []
	var killer: String = String(g._truth.get("killer", ""))
	var out: Array = []
	for id in sim.order:
		if id == v or id == "player" or id == killer or not sim.alive(sim.people[id]) or not (sim.people[id].group in ["adult", "elder"]):
			continue
		var r: String = relation(g, v, String(id))
		if r != "":
			out.append({"id": String(id), "rel": r, "score": maxf(sim.people[v].affinity(String(id)), sim.people[id].affinity(v)) + (30.0 if r in ["spouse", "child", "parent", "sibling"] else 0.0)})
	out.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and String(a["id"]) < String(b["id"])))
	return out


static func loved_one(g: RefCounted) -> String:
	var c: Array = circle(g)
	if not c.is_empty():
		return String(c[0]["id"])
	return String(g.case.get("found_by", ""))


static func told_key(g: RefCounted, npc: String) -> String:
	return "told|%s|%s" % [g.case.get("id", ""), npc]


# ------------------------------------------------------------------ the dossier
static func known_rows(g: RefCounted) -> Dictionary:
	var out := {}
	var cid: String = String(g.case.get("id", "#"))
	for row in _d()["rows"]:
		var id := "who_%s_%s" % [cid, String(row["key"])]
		if g.det.known.has(id):
			out[String(row["key"])] = g.det.known[id]
	return out


## The dossier: [{key, label, known, text}] and how many rows you hold.
static func dossier(g: RefCounted) -> Dictionary:
	var known: Dictionary = known_rows(g)
	var rows: Array = []
	for row in _d()["rows"]:
		var e: Dictionary = known.get(String(row["key"]), {})
		rows.append({"key": row["key"], "label": row["label"], "known": not e.is_empty(), "text": String(e.get("text", ""))})
	return {"rows": rows, "count": known.size(), "empty": String(_d()["dossier_empty"])}


static func _fill(tmpl: String, g: RefCounted, npc: String, row: String) -> String:
	var sim: RefCounted = g.sim
	var v: String = String(g.case.get("victim", ""))
	var p: RefCounted = sim.people[v]
	var haunt: String = ""
	if not p.haunts.is_empty():
		haunt = g.place_name(String(p.haunts[0]))
	elif p.work != "":
		haunt = g.place_name(String(p.work))
	else:
		haunt = "the front room"
	var loved: String = loved_one(g)
	return tmpl.replace("{v}", CaseEngine.first(sim, v)).replace("{n}", CaseEngine.first(sim, npc) if npc != "" else "someone").replace("{w}", Brief.clock_text(float(p.wake))).replace("{h}", haunt).replace("{m}", CaseEngine.first(sim, loved) if loved != "" else "someone")


static func _row_text(g: RefCounted, row: String, npc: String) -> String:
	var d: Dictionary = _d()
	var cid: String = String(g.case.get("id", ""))
	var v: String = String(g.case.get("victim", ""))
	match row:
		"routine": return _fill(_pick(d["routine"], cid + "|routine"), g, npc, row)
		"kindness": return _fill(_pick(d["kindness"], cid + "|kind"), g, npc, row)
		"planning": return _fill(_pick(d["planning"], cid + "|plan"), g, npc, row)
		"loved":
			var lo: String = loved_one(g)
			var rel: String = relation(g, v, lo)
			if rel == "":
				rel = "friend"
			return _fill(String(d["loved"][rel]).replace("{n}", CaseEngine.first(g.sim, lo)), g, npc, row)
	return ""


## Add one dossier row to the notebook (a claim about the dead). `npc` is who told you ("" for the eulogy).
static func _learn_row(g: RefCounted, row: String, npc: String) -> Dictionary:
	var d: Dictionary = _d()
	var det: RefCounted = g.det
	var cid: String = String(g.case.get("id", ""))
	var pred := ""
	var label := ""
	for r in d["rows"]:
		if r["key"] == row:
			pred = String(r["pred"])
			label = String(r["label"])
	var text: String = _row_text(g, row, npc)
	var subject: String = String(g.case.get("victim", ""))
	var tmpl: Array = [Claims.make("said", loved_one(g) if row == "loved" else subject, pred, "", -1.0, row, 0.9)]
	var e := {"id": "who_%s_%s" % [cid, row], "title": "Who they were: %s" % label.to_lower(), "text": text, "kind": "testimony", "source": npc if npc != "" else "chapel", "day": int(g.sim.day)}
	e["claims"] = Claims.emit(g._truth, tmpl, e["source"], text)
	return e if det.learn(e) else {}


## Ask someone who knew the dead to tell you who they were. Returns {ok, text, learned, minutes}.
static func remember(g: RefCounted, npc: String) -> Dictionary:
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	var d: Dictionary = _d()
	var v: String = String(g.case.get("victim", ""))
	var rel: String = relation(g, v, npc)
	if rel == "":
		return {"ok": false, "text": "%s hardly knew them. There is nothing to ask." % CaseEngine.first(sim, npc), "learned": [], "minutes": 0}
	var have: Dictionary = known_rows(g)
	var cid: String = String(g.case.get("id", ""))
	var open_gate: bool = bool(det.compassion.get(npc, false)) or bool(det.funerals.get(cid, false)) or sim.people[npc].affinity("player") >= 15.0 or det.skill("empathy") >= 5
	var pick := ""
	var gated := false
	for r in ORDER:
		if have.has(r):
			continue
		if r in GATED and not open_gate:
			gated = true
			continue
		pick = r
		break
	if pick == "":
		if gated:
			return {"ok": false, "text": Prose.clean(_pick(d["refuse"], cid + npc).replace("{n}", CaseEngine.first(sim, npc)).replace("{v}", CaseEngine.first(sim, v))), "learned": [], "minutes": 4}
		return {"ok": true, "text": "%s has told you what they can. You know them as well as the living can know the dead." % CaseEngine.first(sim, npc), "learned": [], "minutes": 0}
	var e: Dictionary = _learn_row(g, pick, npc)
	var intro: String = _pick(d["remember"][pick], cid + npc + pick)
	var lines: Array = [_fill(intro, g, npc, pick), e.get("text", "")]
	var learned: Array = []
	if not e.is_empty():
		learned.append(e)
		det.gain_xp(6)
	sim.people[npc].bump("player", 3.0, 2.0)
	return {"ok": true, "text": Prose.clean("\n\n".join(lines)), "learned": learned, "minutes": 8}


# ------------------------------------------------------------------ telling the family
static func can_tell(g: RefCounted, npc: String) -> bool:
	var v: String = String(g.case.get("victim", ""))
	return v != "" and g.sim.people.has(v) and g.sim.people[v].dead and relation(g, v, npc) != "" and not g.det.told.has(told_key(g, npc)) and g.sim.alive(g.sim.people[npc])


## The scene. `approach`: "direct", "gentle" (sit with them first) or "ask" (straight to questions). Returns {ok, text, learned, minutes, compassion}.
static func tell(g: RefCounted, npc: String, approach: String) -> Dictionary:
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	var d: Dictionary = _d()
	var v: String = String(g.case.get("victim", ""))
	var rel: String = relation(g, v, npc)
	if rel == "" or not sim.people.has(v):
		return {"ok": false, "text": "There is no one to tell.", "learned": [], "minutes": 0, "compassion": false}
	if det.told.has(told_key(g, npc)):
		return {"ok": false, "text": _pick(d["tell_closed"], npc).replace("{n}", CaseEngine.first(sim, npc)), "learned": [], "minutes": 0, "compassion": false}
	if not (approach in ["direct", "gentle", "ask"]):
		approach = "direct"
	det.told[told_key(g, npc)] = approach
	var cid: String = String(g.case.get("id", ""))
	var pool: Array = d["tell"][rel][approach]
	var scene: String = _fill(_pick(pool, cid + npc + approach), g, npc, "")
	var after: String = _fill(String(d["tell_after"][approach]), g, npc, "")
	var lines: Array = [scene, after]
	var minutes := 15
	var learned: Array = []
	var comp := false
	var p: RefCounted = sim.people[npc]
	match approach:
		"gentle":
			minutes = 45
			det.add_stress(-3.0)
			p.bump("player", 12.0, 10.0)
			p.remember(int(sim.day), "player", "sat with me when I was told", 3.0)
			det.compassion[npc] = true
			comp = true
			det.gain_xp(10)
			if det.check("empathy", 3) == "pass":
				lines.append(_fill(_pick(d["tell_gift"], cid + npc), g, npc, ""))
				var row: Dictionary = remember(g, npc)
				if not (row["learned"] as Array).is_empty():
					learned.append_array(row["learned"])
					lines.append(String(row["text"]))
		"direct":
			minutes = 15
			det.add_stress(3.0)
			p.bump("player", 2.0, 2.0)
			det.gain_xp(4)
		"ask":
			minutes = 10
			det.add_stress(2.0)
			p.bump("player", -8.0, -6.0)
			det.gain_xp(2)
	var text := Prose.clean("\n\n".join(lines))
	var e := {"id": "told_%s_%s" % [cid, npc], "title": "Telling %s" % CaseEngine.first(sim, npc), "text": text, "kind": "testimony", "source": npc, "day": int(sim.day)}
	e["claims"] = Claims.emit(g._truth, [Claims.make("said", npc, "told_of_death", "", -1.0, approach, 1.0)], npc, text)
	if det.learn(e):
		learned.append(e)
	return {"ok": true, "text": text, "learned": learned, "minutes": minutes, "compassion": comp}


# ------------------------------------------------------------------ the funeral
## Two rows of the dossier come free from the eulogy; the chapel remembers who came (see DetectiveGame.attend_funeral).
static func eulogy(g: RefCounted) -> String:
	var d: Dictionary = _d()
	var cid: String = String(g.case.get("id", ""))
	var have: Dictionary = known_rows(g)
	for r in ["routine", "kindness"]:
		if not have.has(r):
			_learn_row(g, r, "")
	return _fill(_pick(d["eulogy"], cid + "|eulogy"), g, "", "")


# ------------------------------------------------------------------ the thing you carry
static func tick(g: RefCounted) -> void:
	var det: RefCounted = g.det
	var cid: String = String(g.case.get("id", ""))
	if cid == "" or not det.has("c_body") or String(det.keepsake.get("case", "")) == cid:
		return
	var d: Dictionary = _d()
	var item: String = _pick(d["keepsake"], cid + "|keep")
	det.keepsake = {"case": cid, "item": item, "family": loved_one(g), "returned": false}
	var text: String = _pick(d["keepsake_found"], cid + "|kf").replace("{i}", item)
	var e := {"id": "keep_%s" % cid, "title": "A small thing of theirs", "text": Prose.clean(text), "kind": "physical", "source": String(g.case.get("scene", "")), "day": int(g.sim.day)}
	e["claims"] = Claims.emit(g._truth, [Claims.make("found", "", "victim_keepsake", String(g.case.get("scene", "")), -1.0, item, 1.0)], String(g.case.get("scene", "")), text)
	det.learn(e)


static func carrying(g: RefCounted) -> String:
	var k: Dictionary = g.det.keepsake
	if k.is_empty() or bool(k.get("returned", false)):
		return String(_d()["carry_none"])
	return Prose.clean(String(_d()["carry"]).replace("{i}", String(k["item"])).replace("{n}", CaseEngine.name_of(g.sim, String(k["family"]))))


static func can_return(g: RefCounted) -> bool:
	var k: Dictionary = g.det.keepsake
	return not k.is_empty() and not bool(k.get("returned", false)) and String(g._truth.get("status", "open")) != "open" and g.sim.people.has(String(k.get("family", "")))


static func return_keepsake(g: RefCounted) -> Dictionary:
	if not can_return(g):
		return {"ok": false, "text": "Not yet. The family would not know what to do with a kindness while the case is still open.", "minutes": 0}
	var k: Dictionary = g.det.keepsake
	var fam: String = String(k["family"])
	var rel: String = relation(g, String(g.case.get("victim", "")), fam)
	if rel == "":
		rel = "friend"
	var text: String = String(_d()["keepsake_return"][rel]).replace("{n}", CaseEngine.first(g.sim, fam)).replace("{i}", String(k["item"]))
	k["returned"] = true
	g.det.keepsake = k
	g.det.add_stress(-8.0)
	g.det.gain_xp(15)
	Reputation.apply(g.det, "keepsake", int(g.sim.day))
	g.sim.people[fam].bump("player", 15.0, 12.0)
	g.chronicle.append({"day": g.sim.day, "text": "%s took %s back to %s." % ["The detective", String(k["item"]), CaseEngine.name_of(g.sim, fam)]})
	return {"ok": true, "text": Prose.clean(text), "minutes": 30}
