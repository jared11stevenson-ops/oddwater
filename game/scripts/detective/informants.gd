extends RefCounted
## Informants and deals. Some residents trade tips for favours: people with something to hide, or who see the town after dark. A tip is a
## claim with a certainty, and it may be false or mistaken (the court finds out which). Favours are scarce, so each tip is a choice. A plea
## deal buys a statement and a quicker end for a reduced sentence: with the right person it closes a case, with the wrong, frightened one it
## puts an innocent in a cell and the killer back on the street.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Resources = preload("res://scripts/detective/resources.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const Brief = preload("res://scripts/sim/brief.gd")

const PLEA_SENTENCE := 12
const INSIDER_JOBS := ["bartender", "bouncer", "odd jobs", "unemployed", "dockhand", "taxi", "bait", "tackle"]


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


## The street's contacts for this case: residents with something to hide or who keep late hours. Chosen by a stable hash, and never the dead or the
## one who found them. (Truth enters only through the secrets they hold, and a contact may be anyone with a secret, so the list names no killer.)
static func pool(g: RefCounted) -> Array:
	var sim: RefCounted = g.sim
	var c: Dictionary = g._truth
	var out: Array = []
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		if id == "player" or not sim.alive(p) or p.taken or p.jailed or not (p.group in ["adult", "elder"]):
			continue
		if id == String(c.get("victim", "")) or id == String(c.get("found_by", "")) or id == String(c.get("killer", "")):
			continue
		var prof: Dictionary = c.get("profiles", {}).get(id, {})
		var insider := false
		for j in INSIDER_JOBS:
			if String(p.job).to_lower().contains(j):
				insider = true
		if String(p.secret) != "" or String(prof.get("role", "")) in ["herring", "decoy"] or insider:
			out.append(String(id))
	out.sort_custom(func(a, b): return absi(hash("%s|contact|%s" % [c.get("id", ""), a])) < absi(hash("%s|contact|%s" % [c.get("id", ""), b])))
	return out.slice(0, 3)


## The three names the street gives you, entered in the notebook the first time as what they are: hearsay about who trades tips.
static func contacts(g: RefCounted) -> Array:
	var det: RefCounted = g.det
	if not det.has("c_body"):
		return []            # the street talks once the case is out; until you have seen the body there is nothing to trade on
	var ids: Array = pool(g)
	var d: Dictionary = Prose.json("detective/informants.json")
	for id in ids:
		if not det.contacts.has(id):
			det.contacts.append(id)
			var txt: String = _pick(d["intro"], "%s|%s" % [g.case.get("id", ""), id]).replace("{n}", CaseEngine.name_of(g.sim, String(id)))
			var e := {"id": "street_%s_%s" % [g.case.get("id", ""), id], "title": "Word on the street", "text": txt, "kind": "testimony", "source": "street", "day": int(g.sim.day)}
			e["claims"] = Claims.emit(g._truth, [Claims.make("said", String(id), "trades_tips", "", -1.0, "", 0.6)], "street", txt)
			det.learn(e)
	return det.contacts.filter(func(x): return ids.has(x))


## One tip, for a favour. Returns {ok, text, learned, minutes}. The subject comes from the real night where the contact is honest, and
## from a grudge or a bad memory where they are not; the notebook gets a claim with the certainty the contact sounded.
static func tip(g: RefCounted, contact: String) -> Dictionary:
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	var c: Dictionary = g._truth
	var d: Dictionary = Prose.json("detective/informants.json")
	if not contacts(g).has(contact):
		return {"ok": false, "text": "You do not know that person trades in tips.", "learned": [], "minutes": 0}
	if not Resources.spend(det, "favours", 1):
		return {"ok": false, "text": _pick(d["broke"], contact), "learned": [], "minutes": 0}
	var nm: String = CaseEngine.name_of(sim, contact)
	var n_prev: int = int(det.told.get("tips|" + contact, 0))
	det.told["tips|" + contact] = n_prev + 1
	var p: RefCounted = sim.people[contact]
	var reliability: float = clampf(0.62 + p.affinity("player") / 250.0 + 0.02 * float(det.skill("streetwise") - 3), 0.35, 0.9)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash("%d|tip|%s|%s|%d" % [g.seed_v, c.get("id", ""), contact, n_prev])
	var night: Dictionary = sim.night.get(int(c["day"]), {})
	var outs: Array = []
	for id in night:
		if id != contact and id != String(c["victim"]) and id != "player" and sim.people.has(id) and sim.alive(sim.people[id]) and not det.told.has("tipsubj|" + String(id)):
			outs.append(String(id))
	outs.sort()
	var lines: Array = [_pick(d["meet"], contact + str(n_prev)).replace("{n}", nm)]
	var tmpl: Array = []
	var cert: float = 0.5 + 0.2 * rnd.randf()
	var learned: Array = []
	if outs.is_empty():
		lines.append(_pick(d["nothing"], contact))
		tmpl.append(Claims.make("said", "", "observation", "", -1.0, "", 0.5))
	else:
		var honest: bool = rnd.randf() < reliability
		var pick: String = String(outs[rnd.randi() % outs.size()])
		var rec: Dictionary = night[pick]
		var t: float = (float(rec["from"]) + minf(float(rec["to"]), float(rec["from"]) + 3.0)) / 2.0
		var place: String = g.place_name(String(rec["lot"]))
		var prof: Dictionary = c.get("profiles", {}).get(pick, {})
		if honest:
			det.told["tipsubj|" + pick] = 1
			if String(prof.get("alibi", "")) == "secret" and rnd.randf() < 0.6:
				lines.append(_pick(d["clear"], contact + pick).replace("{s}", CaseEngine.name_of(sim, pick)).replace("{p}", place).replace("{t}", Brief.clock_text(fposmod(t, 24.0))))
				tmpl.append(Claims.make("said", pick, "elsewhere", String(rec["lot"]), float(rec["from"]), "", cert, "true", float(rec["to"])))
			else:
				lines.append(_pick(d["saw"], contact + pick).replace("{s}", CaseEngine.name_of(sim, pick)).replace("{p}", place).replace("{t}", Brief.clock_text(fposmod(t, 24.0))))
				tmpl.append(Claims.make("said", pick, "seen_out_at_night", String(rec["lot"]), t, "", cert, "true"))
		else:
			var pool_ids: Array = []
			for oid in sim.order:
				var po: RefCounted = sim.people[oid]
				if oid != "player" and oid != contact and sim.alive(po) and po.group in ["adult", "elder"] and not night.has(oid) and oid != String(c["victim"]):
					pool_ids.append(String(oid))
			if pool_ids.is_empty():
				pool_ids = outs
			var liar_pick: String = String(pool_ids[rnd.randi() % pool_ids.size()])
			var lot_f: String = String(rec["lot"])
			lines.append(_pick(d["false"], contact + liar_pick).replace("{s}", CaseEngine.name_of(sim, liar_pick)).replace("{p}", g.place_name(lot_f)).replace("{t}", Brief.clock_text(fposmod(t, 24.0))).replace("{n}", CaseEngine.first(sim, contact)))
			tmpl.append(Claims.make("said", liar_pick, "seen_out_at_night", lot_f, t, "", cert, "false"))
	var text := Prose.clean("\n".join(lines))
	var e := {"id": "tip_%s_%d" % [contact, n_prev], "title": "%s's tip" % CaseEngine.first(sim, contact), "text": text, "kind": "testimony", "source": contact, "day": int(sim.day)}
	e["claims"] = Claims.emit(c, tmpl, contact, text)
	if det.learn(e):
		learned.append(e)
		det.gain_xp(6)
	return {"ok": true, "text": text, "learned": learned, "minutes": 20}


# ------------------------------------------------------------------ plea deals
## Offer the person in custody a plea. Costs two favours (the DA's goodwill); one comes back if they refuse. Returns {ok, accepted, text, res}
## where `res` is shaped like a trial result so the court can conclude it. The guilty confess with the held-back detail and the exhausted
## innocent may sign anyway: a wrong deal jails them and leaves the killer free.
static func deal(g: RefCounted, target: String) -> Dictionary:
	var sim: RefCounted = g.sim
	var det: RefCounted = g.det
	var c: Dictionary = g._truth
	var d: Dictionary = Prose.json("detective/informants.json")
	if String(g.court.get("custody", "")) == "" or String(g.court["custody"]) != target:
		return {"ok": false, "accepted": false, "text": _pick(d["deal_closed"], target), "res": {}}
	for dl in det.deals:
		if dl["target"] == target and int(dl["case"]) == int(c["day"]):
			return {"ok": false, "accepted": false, "text": d["deal_done"], "res": {}}
	if not Resources.spend(det, "favours", 2):
		return {"ok": false, "accepted": false, "text": _pick(d["broke"], target), "res": {}}
	var nm: String = CaseEngine.name_of(sim, target)
	var guilty: bool = target == String(c["killer"])
	var sess: Dictionary = g.court.get("sess", {})
	var fatigue: float = float(sess.get("fatigue", 0.0))
	var rapport: float = float(sess.get("rapport", 0.0))
	var n_sess: int = int(sess.get("sessions", 0))
	var pr: Dictionary = det.proof_against(target)
	var weight: float = float(int(pr["opportunity"]) + int(pr["means"]) + int(pr["motive"]) + int(pr["link"])) / 20.0
	var p_accept: float = (0.30 + 0.08 * float(n_sess) + fatigue / 220.0 + rapport / 260.0 + weight) if guilty else (0.06 + 0.07 * float(n_sess) + fatigue / 160.0)
	p_accept = clampf(p_accept, 0.05, 0.92)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash("%d|deal|%s|%s" % [g.seed_v, c.get("id", ""), target])
	var lines: Array = [_pick(d["deal_offer"], target).replace("{n}", nm)]
	var accepted: bool = rnd.randf() < p_accept
	det.deals.append({"target": target, "case": int(c["day"]), "day": int(sim.day), "kind": "plea", "wrongful": accepted and not guilty})
	if not accepted:
		Resources.gain(det, "favours", 1)
		lines.append(_pick(d["deal_refuse"], target).replace("{n}", nm))
		sess["fatigue"] = float(sess.get("fatigue", 0.0)) + 8.0
		return {"ok": true, "accepted": false, "text": Prose.clean("\n".join(lines)), "res": {}}
	var tmpl: Array = []
	if guilty:
		lines.append(_pick(d["deal_guilty"], target).replace("{n}", nm))
		tmpl.append(Claims.make("said", target, "confessed", String(c["scene"]), -1.0, String(c.get("held_back", "")), 1.0, "true"))
	else:
		lines.append(_pick(d["deal_false"], target).replace("{n}", nm))
		tmpl.append(Claims.make("said", target, "confessed", String(c["scene"]), -1.0, "", 0.9, "false"))
	var text := Prose.clean("\n".join(lines))
	var e := {"id": "plea_%s" % target, "title": "%s's plea statement" % CaseEngine.first(sim, target), "text": text, "kind": "confession", "source": target, "day": int(sim.day)}
	e["claims"] = Claims.emit(c, tmpl, target, text)
	det.learn(e)
	var res := {"verdict": "guilty", "confidence": 100.0, "attacks": [], "sentence": PLEA_SENTENCE, "wrongful": not guilty, "target": target, "plea": true}
	return {"ok": true, "accepted": true, "text": text, "res": res}
