extends RefCounted
## What the detective can DO with a case: examine a scene, question people, press them with evidence, search, check records,
## send things to the lab, ask for a warrant, and accuse. Every operation reads the case's truth and the sim's real state, and returns
## plain results ({text, learned, minutes}) for the screens to show. Nothing here ever blocks: a failed check gives a partial read.

const Data = preload("res://scripts/core/data.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Relationship = preload("res://scripts/sim/relationship.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Voice = preload("res://scripts/detective/voice.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")

const SKILL_LABEL := {"observation": "Observation", "empathy": "Empathy", "authority": "Authority", "charm": "Charm", "logic": "Logic",
	"forensics": "Forensics", "occult": "Occult", "streetwise": "Streetwise"}


# =========================================================================== scenes and places
static func spots_at(sim: RefCounted, c: Dictionary, lot: String) -> Array:
	var out: Array = []
	if lot == c["scene"]:
		var cb: Dictionary = Prose.json("detective/casebook.json")
		for s in cb["scene_spots"][c["scene_kind"]]:
			out.append({"id": s[0], "label": s[1]})
		return out
	var l: Dictionary = Brief.layout().by_id.get(lot, {})
	if l.is_empty():
		return out
	if l["kind"] in ["house", "home"]:
		out.append({"id": "search", "label": "Search the house"})
	elif l["kind"] == "landmark":
		out.append({"id": "records", "label": "Ask to see the records"})
	if lot in ["pageant_green", "marina", "launch_quay"]:
		out.append({"id": "weapon", "label": "Search the grounds"})
	return out


static func _entry_from_clue(c: Dictionary, clue: Dictionary, day: int) -> Dictionary:
	return {"id": clue["id"], "title": clue["title"], "text": clue["text"], "kind": "physical", "source": clue["lot"], "claims": _claims_for(c, clue.get("claims", []), clue["lot"], clue["text"], clue["lot"]), "day": day, "lab": clue.get("lab", false)}


## Claim templates become notebook claims here (and nowhere else): private tags go to the truth's map, an observation with no
## particular claim still gets a structured one so every entry in the notebook is claims all the way down.
static func _claims_for(c: Dictionary, templates: Array, source: String, text: String, place: String = "") -> Array:
	var t: Array = templates
	if t.is_empty():
		t = [Claims.make("found", "", "observation", place)]
	return Claims.emit(c, t, source, text)


static func _gate_text(gate: Dictionary) -> String:
	if gate.has("skill"):
		return "%s %d" % [SKILL_LABEL.get(gate["skill"], gate["skill"]), int(gate["level"])]
	return ""


## Every result passes through here: a new name may come into view, the text is cleaned, and a frayed mind adds its own line.
static func _finish(sim: RefCounted, c: Dictionary, det: RefCounted, r: Dictionary, salt: String) -> Dictionary:
	var nm := CaseEngine.emerge(sim, c, det)
	if nm != "":
		r["text"] = String(r["text"]) + "\n\n(A new name for the board: %s.)" % CaseEngine.name_of(sim, nm)
		r["emerged"] = nm
	var t := Prose.clean(String(r["text"]))
	var shown := Voice.dread(t, det.stress, "%s|%d|%d" % [salt, det.known.size(), det.statements.size()])
	r["dread"] = shown != t
	r["text"] = shown
	return r


## Look at one thing at one place. Returns {text, learned: [entries], minutes}.
static func examine(sim: RefCounted, c: Dictionary, det: RefCounted, lot: String, spot: String) -> Dictionary:
	var learned: Array = []
	var lines: Array = []
	var warrant_ok := true
	var owners: Array = sim.order.filter(func(id): return sim.people[id].home == lot)
	if spot == "search":
		warrant_ok = false
		for o in owners:
			if det.warrants.get(o, false) or o == "player":
				warrant_ok = true
		if not warrant_ok:
			return {"text": "You have no right to search this house. You'd need a warrant, and the judge wants real evidence before signing one.", "learned": [], "minutes": 5}
	var candidates: Array = []
	for id in c["clues"]:
		var cl: Dictionary = c["clues"][id]
		if cl["lot"] != lot:
			continue
		if spot == "search" and cl["spot"] in ["shoes", "coat", "weapon"] and cl["lot"] == lot:
			candidates.append(cl)
		elif spot == "records" and cl["spot"] == "records":
			candidates.append(cl)
		elif spot == "weapon" and cl["spot"] == "weapon":
			candidates.append(cl)
		elif cl["spot"] == spot and lot == c["scene"]:
			candidates.append(cl)
	if candidates.is_empty():
		return {"text": "You look carefully. Nothing here matters to the case.", "learned": [], "minutes": 10}
	var any_new := false
	for cl in candidates:
		if det.has(cl["id"]):
			lines.append("(You have already logged: %s.)" % cl["title"])
			continue
		if cl.get("gone", false):
			lines.append("There was something here once: %s. It has been cleared away, and the case is too old now to get it back." % String(cl["title"]).to_lower())
			continue
		if cl.get("needs", "") != "" and not det.has(cl["needs"]):
			lines.append("There's something here, but you don't know yet what it should be compared with.")
			continue
		var gate: Dictionary = cl["gate"]
		var res: String = det.check(gate["skill"], int(gate["level"])) if gate.has("skill") else "pass"
		if res == "pass":
			var e := _entry_from_clue(c, cl, int(sim.day))
			if det.learn(e):
				learned.append(e)
				lines.append("%s: %s" % [cl["title"], cl["text"]])
				any_new = true
		elif res == "partial":
			lines.append("Something is off here, and you can almost see it. [%s %d to be sure]" % [SKILL_LABEL[gate["skill"]], int(gate["level"])])
		else:
			lines.append("There's detail here you can't read yet. [%s %d]" % [SKILL_LABEL[gate["skill"]], int(gate["level"])])
	if any_new:
		det.gain_xp(10 * learned.size())
		for e in learned:
			if c["clues"].get(e["id"], {}).get("eerie", false):
				det.add_stress(6.0)
				lines.append("(Something about this will stay with you. Stress +6.)")
		if spot == "body":
			det.add_stress(8.0)
			lines.append("(The scene gets to you. Stress +8.)")
	return _finish(sim, c, det, {"text": "\n".join(lines), "learned": learned, "minutes": 15}, "ex|%s|%s" % [lot, spot])


# =========================================================================== questions
static func _fact_entry(c: Dictionary, f: Dictionary, sim: RefCounted, npc: String) -> Dictionary:
	return {"id": f["id"], "title": "%s says" % CaseEngine.first(sim, npc), "text": f["text"], "kind": "testimony", "source": npc, "claims": _claims_for(c, f.get("claims", []), npc, f["text"]), "day": int(sim.day)}


static func _reveal_ok(sim: RefCounted, det: RefCounted, npc: String, f: Dictionary, c: Dictionary = {}) -> Dictionary:
	if f.get("cult", false) and not Reputation.chapel_opens(det):
		return {"ok": false, "text": "%s will not speak of it. \"That's chapel business. And the chapel says you are not a friend of this town.\"" % CaseEngine.first(sim, npc)}
	match String(f["reveal"]):
		"free":
			return {"ok": true}
		"rapport":
			var aff: float = sim.people[npc].affinity("player")
			if aff >= 10.0 or det.skill("charm") >= 4 or det.skill("empathy") >= 5:
				return {"ok": true}
			var line: String = Voice.say("rapport_refuse", sim, c, npc, {"n": CaseEngine.first(sim, npc)}) if not c.is_empty() else "%s glances away. \"I don't know you well enough for that.\"" % CaseEngine.first(sim, npc)
			return {"ok": false, "text": line + " [Charm 4, or earn their trust first]"}
		"pressure":
			var needs: Array = f.get("needs", [])
			var ok := not needs.is_empty()
			for n in needs:
				if not det.has(n):
					ok = false
			if ok or det.skill("authority") >= 6 or (f.get("cult", false) and Reputation.chapel_tier(det) in ["welcome", "trusted"] and (needs.is_empty() or det.has(String(needs[0])))):
				return {"ok": true}
			return {"ok": false, "text": Voice.say("pressure_quiet", sim, c, npc, {"n": CaseEngine.first(sim, npc)}) if not c.is_empty() else "%s goes quiet." % CaseEngine.first(sim, npc)}
	return {"ok": true}


## Write a statement in the log once: the same words from the same person on the same subject are not a second statement.
static func _log(det: RefCounted, sim: RefCounted, npc: String, topic: String, about: String, text: String) -> void:
	for st in det.statements:
		if st["npc"] == npc and st["topic"] == topic and st["about"] == about and st["text"] == text:
			return
	det.statements.append({"day": int(sim.day), "npc": npc, "topic": topic, "about": about, "text": text})


## Would asking this again turn up something new (a line that was gated before and is open now)?
static func _has_new(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, topic: String, about: String) -> bool:
	for fid in c["facts"]:
		var f: Dictionary = c["facts"][fid]
		if det.has(fid) or not f["knowers"].has(npc) or f.get("faded", false):
			continue
		var match_topic: bool = false
		match topic:
			"alibi": match_topic = f["topic"] == "alibi" and f["about"] == about
			"victim": match_topic = f["topic"] == "victim"
			"suspects": match_topic = f["topic"] in ["suspects", "owner"]
			"saw": match_topic = f["topic"] == "saw"
			"person": match_topic = f["topic"] == "suspects" and f["about"] == about
		if match_topic and _reveal_ok(sim, det, npc, f, c)["ok"]:
			return true
	return false


## A fact told in the voice of someone who may be lying, hazy or simply too long ago to remember.
static func _tell_fact(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, f: Dictionary, lines: Array, learned: Array) -> void:
	if f.get("faded", false) and not det.has(f["id"]):
		lines.append("\"%s\"" % Voice.say("cold_forgot", sim, c, npc))
		return
	var gate: Dictionary = _reveal_ok(sim, det, npc, f, c)
	if not gate["ok"]:
		lines.append(gate["text"])
		return
	lines.append("\"%s\"" % f["text"])
	if f.get("false", false) and det.check("empathy", 4) == "pass":
		lines.append("[Empathy] The eyes slide off on the one word that matters. This is a performance, and a practised one.")
	elif f.get("unreliable", false) and det.check("logic", 3) == "pass":
		lines.append("[Logic] The times don't sit together. Treat this as a rough guide, not a clock.")
	var e := _fact_entry(c, f, sim, npc)
	if det.learn(e):
		learned.append(e)


## Ask someone a question. Topics: alibi (about = who; "" means themselves), victim, suspects, saw.
static func ask(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, topic: String, about: String = "") -> Dictionary:
	var learned: Array = []
	var lines: Array = []
	var p: RefCounted = sim.people[npc]
	var victim: String = c["victim"]
	var minutes := 6
	if not sim.alive(p) and npc != victim:
		return {"text": "%s is not here. They left Little Mercy, and nobody is saying where." % CaseEngine.name_of(sim, npc), "learned": [], "minutes": 0}
	var dmg: Dictionary = c.get("damaged", {})
	if dmg.has(npc) and int(sim.day) < int(dmg[npc]["until"]) and topic != "person":
		var rr := {"text": Voice.say("refuse_damaged", sim, c, npc, {"n": CaseEngine.first(sim, npc)}), "learned": [], "minutes": 3, "refused": true}
		return _finish(sim, c, det, rr, "dm|%s" % npc)
	var key := "%s|%s|%s" % [npc, topic, about]
	var asked_before: bool = int(det.asked.get(key, 0)) > 0
	det.asked[key] = int(det.asked.get(key, 0)) + 1
	if asked_before and not _has_new(sim, c, det, npc, topic, about):
		var rep := {"text": Voice.say("repeat", sim, c, npc), "learned": [], "minutes": 2, "repeat": true}
		return _finish(sim, c, det, rep, "rp|%s|%d" % [key, det.asked[key]])
	match topic:
		"alibi":
			if about == "" or about == npc:
				if c["profiles"].has(npc):
					var pr: Dictionary = c["profiles"][npc]
					lines.append("\"%s\"" % pr["claim"])
					if det.check("empathy", 3) == "pass":
						lines.append("[Empathy] %s: %s." % [CaseEngine.first(sim, npc), "hiding something" if pr["lie"] else "an open face; this reads true"])
				elif npc == victim:
					lines.append("(The dead don't answer.)")
				else:
					lines.append("\"%s\"" % Voice.say("alibi_default", sim, c, npc))
			elif c["profiles"].has(about) and c.get("relatives", {}).get(about, []).has(npc):
				var pr2: Dictionary = c["profiles"][about]
				if pr2["lie"]:
					lines.append("\"%s was home with me all night. I'd swear to it.\"" % CaseEngine.first(sim, about))
					if det.check("empathy", 4) == "pass":
						lines.append("[Empathy] %s is protecting someone. They believe what they're saying, or need to." % CaseEngine.first(sim, npc))
				else:
					lines.append("\"%s told me where they were that night, and it checks out: %s\"" % [CaseEngine.first(sim, about), String(pr2["claim"])])
			else:
				var found := false
				for fid in c["facts"]:
					var f: Dictionary = c["facts"][fid]
					if f["topic"] == "alibi" and f["about"] == about and f["knowers"].has(npc):
						found = true
						_tell_fact(sim, c, det, npc, f, lines, learned)
				if not found:
					lines.append("\"%s\"" % Voice.say("alibi_unknown", sim, c, npc, {"about": CaseEngine.first(sim, about)}))
		"victim", "know":
			if npc == victim:
				lines.append("(The dead don't answer.)")
				return _finish(sim, c, det, {"text": "\n".join(lines), "learned": [], "minutes": 0}, "ask|%s|%s|%s" % [npc, topic, about])
			var st: String = Relationship.stage(p.affinity(victim), p.trust(victim))
			var intent: String = {"best friend": "victim_close", "close friend": "victim_close", "friend": "victim_friend", "acquaintance": "victim_acq", "stranger": "victim_stranger", "on bad terms": "victim_bad", "rival": "victim_bad", "enemy": "victim_enemy"}.get(st, "victim_acq")
			lines.append("\"%s? %s\"" % [CaseEngine.first(sim, victim), Voice.say(intent, sim, c, npc, {"v": CaseEngine.first(sim, victim)})])
			_facts_for(sim, c, det, npc, "victim", lines, learned)
			if topic == "know":
				# "What do you know?" is open-ended: they give you the lay of it, and point you at what they could say if asked properly
				var more := false
				for fid in c["facts"]:
					var f9: Dictionary = c["facts"][fid]
					if f9["knowers"].has(npc) and f9["topic"] in ["saw", "suspects", "owner"] and not det.has(fid) and not f9.get("faded", false):
						more = true
				if more:
					lines.append("\"%s\"" % Voice.say("know_more", sim, c, npc, {"n": CaseEngine.first(sim, npc)}))
		"suspects":
			var named := 0
			var dislikes: Array = []
			for sid in p.rel:
				if sid != npc and sid != "player" and sid != victim and sim.people.has(sid) and sim.alive(sim.people[sid]) and p.affinity(sid) <= -20.0:
					dislikes.append(sid)
			dislikes.sort_custom(func(a, b): return p.affinity(a) < p.affinity(b))
			for sid in dislikes:
				if named < 2:
					var gtxt := "Between you and me, I don't trust %s." % CaseEngine.name_of(sim, sid)
					lines.append("\"%s\"" % gtxt)
					named += 1
					var ge := {"id": "gossip_%s_%s" % [npc, sid], "title": "%s distrusts %s" % [CaseEngine.first(sim, npc), CaseEngine.first(sim, sid)], "text": gtxt, "kind": "testimony", "source": npc, "day": int(sim.day)}
					ge["claims"] = _claims_for(c, [Claims.make("said", sid, "distrusted_by", "", -1.0, "", 0.6)], npc, gtxt)
					if det.learn(ge):
						learned.append(ge)
			_facts_for(sim, c, det, npc, "suspects", lines, learned)
			_facts_for(sim, c, det, npc, "owner", lines, learned)
			if npc == c["killer"] and c.get("helper", false) and det.check("logic", 3) == "pass":
				var slip := {"id": "f_helper_slip", "title": "%s knows too much" % CaseEngine.first(sim, npc), "kind": "testimony", "source": npc, "day": int(sim.day),
					"text": "%s was eager to help and said the room had been 'arranged', every piece in its place. Nobody has told %s anything about the room." % [CaseEngine.name_of(sim, npc), CaseEngine.first(sim, npc)],
					"claims": []}
				slip["claims"] = _claims_for(c, [Claims.make("said", npc, "knew_unreleased", "", -1.0, "arranged")], npc, slip["text"])
				if det.learn(slip):
					learned.append(slip)
					lines.append("[Logic] Nobody has told %s a word about how the scene looked. They said 'arranged'." % CaseEngine.first(sim, npc))
			if lines.is_empty():
				lines.append("\"%s\"" % Voice.say("suspects_none", sim, c, npc, {"v": CaseEngine.first(sim, victim)}))
		"saw":
			_facts_for(sim, c, det, npc, "saw", lines, learned)
			if lines.is_empty():
				lines.append("\"%s\"" % Voice.say("saw_none", sim, c, npc))
		"person":
			if about != "" and sim.people.has(about):
				var px: RefCounted = sim.people[about]
				var rel_word: String = Relationship.describe(sim, npc, about)
				var rel_txt: String = ("My " + rel_word) if rel_word in ["partner", "parent", "child", "sibling", "housemate"] else ("We're " + rel_word)
				lines.append("\"%s? %s, %s. %s.\"" % [CaseEngine.first(sim, about), rel_txt, Prose.job_np(px.job), _habit(px)])
				if c.get("relatives", {}).get(about, []).has(npc) and c["profiles"].has(about) and c["profiles"][about]["lie"]:
					lines.append("\"%s\"" % Voice.say("cover_good_person", sim, c, npc))
				for fid in c["facts"]:
					var f2: Dictionary = c["facts"][fid]
					if f2["topic"] == "suspects" and f2["about"] == about and f2["knowers"].has(npc):
						lines.append("\"%s\"" % f2["text"])
						var e3 := _fact_entry(c, f2, sim, npc)
						if det.learn(e3):
							learned.append(e3)
	lines = lines.filter(func(l): return String(l).strip_edges() != "" and String(l) != "\"\"")
	if lines.is_empty():
		lines.append("%s thinks about it. \"I've told you what I've got. Ask me something particular and I'll try.\"" % CaseEngine.first(sim, npc))
	var text := "\n".join(lines)
	_log(det, sim, npc, topic, about, text)
	if not learned.is_empty():
		det.gain_xp(12 * learned.size())
	# asking about the dead is hard on the living
	p.bump("player", -1.0 if topic in ["victim", "suspects"] and not asked_before else 0.0, 0.0)
	return _finish(sim, c, det, {"text": text, "learned": learned, "minutes": minutes}, "ask|%s|%s|%s" % [npc, topic, about])


static func _habit(p: RefCounted) -> String:
	var quirk: String = Prose.sentence(String(p.quirk)) if p.quirk != "" else "Keeps to routine"
	return "%s. %s" % [quirk, ("Spends spare time " + p.hobby) if p.hobby != "" else "Not much of a hobbyist"]


static func _facts_for(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, topic: String, lines: Array, learned: Array) -> void:
	for fid in c["facts"]:
		var f: Dictionary = c["facts"][fid]
		if f["topic"] != topic or not f["knowers"].has(npc):
			continue
		_tell_fact(sim, c, det, npc, f, lines, learned)


static func _opinion(stage: String) -> String:
	match stage:
		"best friend", "close friend": return "One of the best. I can't believe it"
		"friend": return "A good neighbour. A good person"
		"acquaintance": return "I knew them to nod to. Kept themselves to themselves"
		"stranger": return "I barely knew them"
		"on bad terms", "rival": return "We didn't get on, I won't lie. I wouldn't wish this on them"
		"enemy": return "I won't pretend to be sorry. But I didn't do it"
	return "I knew them"


## Put something you have found in front of someone.
static func present(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, entry_id: String) -> Dictionary:
	var learned: Array = []
	var text := ""
	if not det.has(entry_id):
		return {"text": "You don't have that.", "learned": [], "minutes": 0}
	var k: String = c["killer"]
	if entry_id == "c_dropped":
		if c["owner_item_knowers"].has(npc):
			var f: Dictionary = c["facts"]["f_owner"]
			var e := _fact_entry(c, f, sim, npc)
			if det.learn(e):
				learned.append(e)
			text = "\"%s\" They don't like having said it." % f["text"]
		elif npc == k:
			text = "%s looks at it a half-second too long. \"Never seen it.\"" % CaseEngine.first(sim, k)
			_log(det, sim, npc, "present", "", text)
			if det.check("empathy", 3) == "pass":
				text += " [Empathy] They're lying. That frightened them."
		else:
			text = "\"%s\"" % Voice.say("present_unknown", sim, c, npc)
	elif entry_id == "f_h1_seen" and c["profiles"].has(npc) and c["profiles"][npc].get("alibi", "") == "secret":
		var f2: Dictionary = c["facts"]["f_h1_secret"]
		var e2 := _fact_entry(c, f2, sim, npc)
		if det.learn(e2):
			learned.append(e2)
		text = "\"%s\"" % f2["text"]
		sim.people[npc].bump("player", -4.0, 0.0)
		if c["profiles"][npc].get("cult", false):
			Reputation.apply(det, "occult_exposed", int(sim.day))
			text += " The chapel will hear that you made them say it."
	elif _cover_cracks(c, npc, entry_id, det):
		var target: String = _covered(c, npc)
		var tname := CaseEngine.first(sim, target)
		var ent := {"id": "cover_" + npc, "title": "%s's cover breaks" % CaseEngine.first(sim, npc), "text": "%s admits it: %s was not home that night. They went out and came back late. They begged you not to say they told you." % [CaseEngine.first(sim, npc), tname],
			"kind": "testimony", "source": npc, "claims": [], "day": int(sim.day)}
		ent["claims"] = _claims_for(c, [Claims.make("said", target, "seen_going_out" if target == k else "was_not_home", "", -1.0, "", 0.7)], npc, ent["text"])
		if det.learn(ent):
			learned.append(ent)
		text = "%s looks at the footage, then at the floor. \"...He went out. I lied. I'm sorry.\"" % CaseEngine.first(sim, npc)
		sim.people[npc].bump("player", -3.0, 0.0)
	elif npc == k and entry_id in ["c_phone", "c_door", "f_kn_saw", "f_vn_saw"]:
		text = "%s's jaw sets. \"Anyone could say that. Anyone could have called from my number.\"" % CaseEngine.first(sim, k)
		det.add_stress(2.0)
	else:
		text = "\"%s\"" % Voice.say("present_unknown", sim, c, npc)
	_log(det, sim, npc, "present", entry_id, text)
	return _finish(sim, c, det, {"text": text, "learned": learned, "minutes": 5}, "pr|%s|%s" % [npc, entry_id])


## Does this piece of evidence break a relative's cover for a liar they are protecting?
static func _covered(c: Dictionary, npc: String) -> String:
	for sid in c["suspects"]:
		if c["profiles"][sid]["lie"] and c.get("relatives", {}).get(sid, []).has(npc):
			return sid
	return ""


static func _cover_cracks(c: Dictionary, npc: String, entry_id: String, det: RefCounted) -> bool:
	var sid: String = _covered(c, npc)
	if sid == "":
		return false
	if entry_id == "f_h1_seen" and c["profiles"][sid].get("alibi", "") == "secret":
		return true
	var e: Dictionary = det.known.get(entry_id, {})
	for cl in e.get("claims", []):
		# a relative knows the walk and the habits of the person they are covering: a figure of that description is them
		if cl["subject"] == "" and cl["predicate"] == "figure_seen" and sid == String(c["killer"]) and String(cl["item"]) == String(c["trait"]) and e.get("kind", "") == "cctv":
			return true
		if cl["subject"] == sid and e.get("kind", "") in ["cctv", "testimony"]:
			for rule in Reasoning.RULES.get(String(cl["predicate"]), []):
				if rule[0] in ["opportunity", "link"]:
					return true
	return false


# =========================================================================== lab, warrants
static func submit_to_lab(sim: RefCounted, c: Dictionary, det: RefCounted, clue_id: String) -> Dictionary:
	if not det.has(clue_id) or not c["clues"].has(clue_id) or not c["clues"][clue_id].get("lab", false):
		return {"text": "Nothing there the lab can use.", "minutes": 5}
	for l in det.lab:
		if l["clue"] == clue_id:
			return {"text": "It's already at the lab.", "minutes": 0}
	for d in det.lab_done:
		if d == clue_id:
			return {"text": "The lab has already reported on that.", "minutes": 0}
	var age: int = int(sim.day) - int(c["day"]) - 1
	var quality := "good" if age < 4 else ("weak" if age < 8 else "spoiled")
	det.lab.append({"clue": clue_id, "ready_day": int(sim.day) + 1, "quality": quality})
	var warn := ""
	if quality == "weak":
		warn = " It has been days; the traces may have started to go."
	elif quality == "spoiled":
		warn = " It has been over a week. The lab sighs. Don't expect much."
	return {"text": "Bagged and sent to the lab. Results tomorrow morning.%s" % warn, "minutes": 15}


## Results that are ready by `day` become notebook entries.
static func lab_results(sim: RefCounted, c: Dictionary, det: RefCounted, day: int) -> Array:
	var out: Array = Prints.compare_results(sim, c, det, day)
	var remaining: Array = []
	for l in det.lab:
		if l.get("print", "") != "":
			remaining.append(l)
		elif int(l["ready_day"]) <= day and c["lab"].has(l["clue"]):
			var r: Dictionary = c["lab"][l["clue"]]
			var tmpl: Array = (r["claims"] as Array).duplicate(true)
			var rtext: String = r["text"]
			match String(l.get("quality", "good")):
				"weak":
					for tp in tmpl:
						tp["certainty"] = float(tp["certainty"]) * 0.5
					rtext += " (The sample had aged. Treat this as weaker than it reads.)"
				"spoiled":
					tmpl = [Claims.make("found", "", "sample_degraded")]
					rtext = "The lab: the sample degraded in storage. There is nothing usable on it now."
			var e := {"id": "lab_" + l["clue"], "title": "Lab report", "text": rtext, "kind": "lab", "source": "lab", "claims": _claims_for(c, tmpl, "lab", rtext), "day": day}
			if det.learn(e):
				out.append(e)
				det.lab_done.append(l["clue"])
				det.gain_xp(20)
		else:
			remaining.append(l)
	det.lab = remaining
	return out


static func request_warrant(sim: RefCounted, c: Dictionary, det: RefCounted, target: String) -> Dictionary:
	if det.warrants.get(target, false):
		return {"ok": true, "text": "You already hold a warrant for %s." % CaseEngine.name_of(sim, target), "minutes": 0}
	var pr: Dictionary = det.proof_against(target)
	var cats := 0
	var total := 0
	for k in ["opportunity", "means", "motive", "link"]:
		if int(pr[k]) > 0:
			cats += 1
		total += int(pr[k])
	if cats >= 2 and total >= 4 and int(pr["exonerate"]) < 3:
		det.warrants[target] = true
		return {"ok": true, "text": "Judge Moss signs it with a sigh. \"Don't make me regret this.\" You may now search %s's house." % CaseEngine.name_of(sim, target), "minutes": 30}
	return {"ok": false, "text": "The judge reads your notes and hands them back. \"That's gossip, not cause. Bring me two kinds of evidence pointing at %s, and enough of it.\"" % CaseEngine.first(sim, target), "minutes": 30}


# =========================================================================== the accusation
## Weigh an accusation. The notebook alone decides whether there is a case to charge at all (so a name said without proof is turned
## away the same way whoever it is). Only once there is, the court looks at the truth: it is the one place claims meet what happened.
## Returns {verdict, score, parts, text}.
static func judge(sim: RefCounted, c: Dictionary, det: RefCounted, culprit: String, motive: String, method: String) -> Dictionary:
	var pr: Dictionary = det.proof_against(culprit)
	var tl: Dictionary = Reasoning.tally(pr)
	var cats: int = tl["cats"]
	var total: int = tl["total"]
	var right_person: bool = culprit == c["killer"]
	var right_motive: bool = motive == c["motive"]
	var right_method: bool = method == c["method"]
	# judge and jury must agree: the same confidence function the trial uses decides whether the case holds
	var jury: Dictionary = {"confidence": 0.0}
	if cats >= 2:
		jury = load("res://scripts/detective/justice.gd").trial(sim, c, det, culprit)
	var enough: bool = cats >= 3 and (int(pr["opportunity"]) > 0 or int(pr["link"]) > 0) and total >= 6 and float(jury["confidence"]) >= 70.0
	var verdict := ""
	var text := ""
	if cats < 2:
		verdict = "insufficient"
		text = "You name %s, and you cannot prove a word of it. The Sheriff will not let you arrest on a hunch." % CaseEngine.name_of(sim, culprit)
	elif right_person and enough:
		verdict = "convicted"
		text = Prose.clean("%s breaks. The evidence holds, line by line. %s" % [CaseEngine.name_of(sim, culprit), _confession(sim, c, right_motive)])
	elif right_person:
		verdict = "released"
		text = "It's the right person, but the case has holes a good lawyer walks through. %s is released pending trial, and knows you know." % CaseEngine.name_of(sim, culprit)
	else:
		verdict = "wrong"
		text = Prose.clean("%s did not do this. What you laid out does not hold against them. The town will not forget that you said so." % CaseEngine.name_of(sim, culprit))
	var score := 0
	score += 40 if right_person else 0
	score += 15 if right_motive else 0
	score += 15 if right_method else 0
	score += mini(cats * 7, 30)
	return {"verdict": verdict, "score": score, "text": text, "cats": cats, "total": total, "right_person": right_person, "right_motive": right_motive, "right_method": right_method, "enough": enough, "case_against": enough}


static func _confession(sim: RefCounted, c: Dictionary, right_motive: bool) -> String:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	return "It was %s: %s. %s" % [cb["motives"][c["motive"]]["label"], c["motive_thing"], "You had it exactly right." if right_motive else "Your theory of why was wrong, but the truth is the same."]


## What happens in the town as a result of a verdict that does not go through a trial. (A conviction goes through the court: see Justice.conclude.)
static func apply_outcome(sim: RefCounted, c: Dictionary, det: RefCounted, res: Dictionary, culprit: String) -> void:
	match String(res["verdict"]):
		"convicted":
			var pk: RefCounted = sim.people[c["killer"]]
			pk.taken = true
			pk.location = ""
			sim.log_event("arrest", c["killer"], "%s was arrested for the murder of %s." % [pk.display, CaseEngine.name_of(sim, c["victim"])])
			Reputation.apply(det, "convicted_killer", int(sim.day))
			det.cases_solved += 1
			det.gain_xp(150)
			det.add_stress(-25.0)
			c["status"] = "solved"
		"released":
			c["status"] = "open"
			c["alerted"] = true
			c["killer_alert"] = int(c.get("killer_alert", 0)) + 1
			Reputation.apply(det, "released_right", int(sim.day))
			det.gain_xp(40)
			det.add_stress(10.0)
		"insufficient":
			Reputation.apply(det, "insufficient", int(sim.day))
			det.add_stress(6.0)
		"wrong":
			wrongly_accused(sim, c, det, culprit, res)


## A wrong name said aloud costs more each time: the accused is left damaged and lingers in the town, the real killer gets time and is
## alerted, and the paper gets a scandal. The cost climbs with every wrong accusation in the same case.
static func wrongly_accused(sim: RefCounted, c: Dictionary, det: RefCounted, culprit: String, res: Dictionary) -> void:
	if not c.has("wrong"):
		c["wrong"] = []
	c["wrong"].append(culprit)
	var n: int = (c["wrong"] as Array).size()
	var scale := Reputation.escalation(n)
	var pa: RefCounted = sim.people[culprit]
	pa.needs["comfort"] = clampf(float(pa.needs["comfort"]) - 35.0 - 10.0 * n, 0.0, 100.0)
	pa.needs["restless"] = clampf(float(pa.needs["restless"]) + 30.0, 0.0, 100.0)
	pa.needs["social"] = clampf(float(pa.needs["social"]) - 30.0, 0.0, 100.0)
	for id in sim.order:
		if id != culprit and sim.people[id].rel.has(culprit):
			sim.people[id].bump(culprit, -6.0 * scale, -4.0 * scale)
	pa.bump("player", -40.0, -40.0)
	pa.remember(int(sim.day), "player", "was named as a murderer in front of the whole street", 3.0)
	sim.seed_rumor(culprit, "The detective dragged %s in for the murder." % pa.display, false, "player", 3, 80.0)
	if not c.has("damaged"):
		c["damaged"] = {}
	c["damaged"][culprit] = {"day": int(sim.day), "n": n, "until": int(sim.day) + 3 + 2 * n}
	Reputation.apply(det, "wrong_accusation", int(sim.day), scale)
	det.cases_failed += 1
	det.add_stress(20.0 + 5.0 * float(n - 1))
	# the real killer is watching. Time is bought: they may clear their house and the longer it goes the more is lost
	c["alerted"] = true
	c["killer_alert"] = int(c.get("killer_alert", 0)) + 1
	res["scandal"] = "WRONGFUL ARREST SCANDAL: %s HELD, THEN FREED. Sources say the detective named %s on a theory and not on proof. %s has not been seen in public since. The Sheriff's office had no comment." % [pa.display.to_upper(), pa.display, CaseEngine.first(sim, culprit)]
	res["damaged"] = culprit
	res["wrong_count"] = n
