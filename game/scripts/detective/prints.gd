extends RefCounted
## Fingerprints. Dust a surface and you lift latent prints, each with an owner and a quality. To say whose a print is you need a
## reference: the victim's (autopsy), eliminations, a suspect who volunteers, or one taken by warrant. The lab compares. Good prints
## are conclusive. Poor ones are only "similar", and similar is not the same as the same.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")

const SPOT_NAMES := {"door": "the door handle", "phone": "the telephone", "desk": "the desk", "floor": "the dropped item", "garden": "the gate"}


## Lift the latents from one surface. Needs the fingerprint kit; Forensics improves the lift.
static func dust(sim: RefCounted, c: Dictionary, det: RefCounted, lot: String, spot: String) -> Dictionary:
	if lot != c["scene"]:
		return {"text": "Nothing here to dust for this case.", "learned": [], "minutes": 5}
	if not det.tools.has("fingerprint kit"):
		return {"text": "You'd need the fingerprint kit.", "learned": [], "minutes": 0}
	var learned: Array = []
	var lines: Array = []
	for l in c["latents"]:
		if l["spot"] != spot:
			continue
		var id: String = "print_" + str(l["id"])
		if det.has(id):
			continue
		var q: int = clampi(int(l["quality"]) + (det.skill("forensics") - 3) * 5, 5, 98)
		var grade := "a clear print" if q >= 60 else ("a partial print" if q >= 35 else "a smudge")
		var e := {"id": id, "title": "Latent print: %s" % SPOT_NAMES.get(spot, spot), "text": "%s on %s (quality %d). Whose is it?" % [grade.capitalize(), SPOT_NAMES.get(spot, spot), q],
			"kind": "print", "source": lot, "day": int(sim.day), "latent": l["id"], "quality": q}
		e["claims"] = Claims.emit(c, [Claims.make("found", "", "latent_print", lot, -1.0, spot, float(q) / 100.0)], lot, String(e["text"]))
		if det.learn(e):
			learned.append(e)
			lines.append(e["text"])
	if lines.is_empty():
		lines.append("The surface is clean, or you've already lifted what there was.")
	else:
		det.gain_xp(8 * learned.size())
	return {"text": "\n".join(lines), "learned": learned, "minutes": 20}


## Ask for a suspect's (or anyone's) prints. The victim's come from the autopsy; others may refuse.
static func take_sample(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String) -> Dictionary:
	if det.samples.get(npc, false):
		return {"ok": true, "text": "You already have their prints on file.", "minutes": 0}
	if npc == c["victim"]:
		det.samples[npc] = true
		return {"ok": true, "text": "Taken at the autopsy.", "minutes": 10}
	var p: RefCounted = sim.people[npc]
	var guilty_and_wary: bool = npc == c["killer"] and not c["gloves"] and absi(hash("%s|%s" % [c["id"], npc])) % 100 < 45
	if det.warrants.get(npc, false) or (p.affinity("player") >= -5.0 and not guilty_and_wary) or det.skill("charm") >= 5:
		det.samples[npc] = true
		return {"ok": true, "text": "%s lets you roll their fingers on the pad. \"Anything to help.\"" % CaseEngine.first(sim, npc), "minutes": 10}
	p.bump("player", -3.0, 0.0)
	var tell := ""
	if det.check("empathy", 3) == "pass":
		tell = " [Empathy] That wasn't annoyance. That was fear."
	return {"ok": false, "text": "%s folds their arms. \"I'd rather not. I know my rights.\"%s" % [CaseEngine.first(sim, npc), tell], "minutes": 5}


## Send a lifted print to be compared with a person's prints. Results next morning; a verified match takes another day.
static func submit_compare(sim: RefCounted, c: Dictionary, det: RefCounted, print_entry: String, target: String) -> Dictionary:
	if not det.has(print_entry) or det.known[print_entry].get("latent", "") == "":
		return {"text": "That isn't a print.", "minutes": 0}
	if not det.samples.get(target, false):
		return {"text": "You have no prints from %s to compare it with." % CaseEngine.name_of(sim, target), "minutes": 0}
	for l in det.lab:
		if l.get("print", "") == print_entry and l.get("target", "") == target:
			return {"text": "That comparison is already at the lab.", "minutes": 0}
	det.lab.append({"clue": "", "print": print_entry, "target": target, "ready_day": int(sim.day) + 1})
	return {"text": "Sent. The examiner will compare it with %s's prints and report tomorrow." % CaseEngine.first(sim, target), "minutes": 10}


## Called when lab results come in: turns pending comparisons into notebook entries.
static func compare_results(sim: RefCounted, c: Dictionary, det: RefCounted, day: int) -> Array:
	var out: Array = []
	var remaining: Array = []
	for l in det.lab:
		if l.get("print", "") == "":
			remaining.append(l)
			continue
		if int(l["ready_day"]) > day:
			remaining.append(l)
			continue
		var e: Dictionary = _compare(sim, c, det, l["print"], l["target"], day)
		if det.learn(e):
			out.append(e)
			det.gain_xp(20)
	det.lab = remaining
	return out


static func _compare(sim: RefCounted, c: Dictionary, det: RefCounted, print_entry: String, target: String, day: int) -> Dictionary:
	var pe: Dictionary = det.known[print_entry]
	var lat: Dictionary = {}
	for l in c["latents"]:
		if l["id"] == pe["latent"]:
			lat = l
	var q: int = int(pe["quality"])
	var tname := CaseEngine.name_of(sim, target)
	var owner: String = lat.get("owner", "unknown")
	var k: String = c["killer"]
	var text := ""
	var claims: Array = []
	var spot: String = String(lat.get("spot", ""))
	if owner == target:
		if q >= 60:
			text = "Conclusive: the print is %s's (16 points of agreement, verified)." % tname
			claims.append(Claims.make("found", target, "print_match", String(c["scene"]), -1.0, spot, 0.95, "true" if target == k else "misleading"))
		elif q >= 35:
			text = "Consistent with %s (7 points). A partial: not enough to be certain." % tname
			claims.append(Claims.make("found", target, "print_match", String(c["scene"]), -1.0, spot, 0.5, "true" if target == k else "misleading"))
		else:
			text = "Unsuitable for comparison: too smudged."
	else:
		if q >= 60:
			text = "Excluded: the print is not %s's." % tname
		elif q >= 35 and target == c.get("lookalike", "") and q < 55:
			text = "Possible match with %s (7 points of similarity). A second examiner should verify. Partial prints can lie." % tname
			claims.append(Claims.make("found", target, "print_match", String(c["scene"]), -1.0, spot, 0.5, "misleading"))
		else:
			text = "No match with %s." % tname
	if claims.is_empty():
		claims.append(Claims.make("found", target, "print_excluded", String(c["scene"])))
	return {"id": "cmp_%s_%s" % [pe["latent"], target], "title": "Print comparison: %s" % tname, "text": text, "kind": "lab", "source": "lab", "claims": Claims.emit(c, claims, "lab", text), "day": day}
