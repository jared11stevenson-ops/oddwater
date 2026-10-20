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

const SKILL_LABEL := {"observation": "Observation", "empathy": "Empathy", "authority": "Authority", "charm": "Charm", "logic": "Logic",
	"forensics": "Forensics", "occult": "Occult", "streetwise": "Streetwise"}


# =========================================================================== scenes and places
static func spots_at(sim: RefCounted, c: Dictionary, lot: String) -> Array:
	var out: Array = []
	if lot == c["scene"]:
		var cb: Dictionary = Data.load_json("detective/casebook.json")
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
	return {"id": clue["id"], "title": clue["title"], "text": clue["text"], "kind": "physical", "source": clue["lot"], "supports": clue["supports"].duplicate(true), "day": day, "lab": clue.get("lab", false)}


static func _gate_text(gate: Dictionary) -> String:
	if gate.has("skill"):
		return "%s %d" % [SKILL_LABEL.get(gate["skill"], gate["skill"]), int(gate["level"])]
	return ""


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
	return {"text": "\n".join(lines), "learned": learned, "minutes": 15}


# =========================================================================== questions
static func _fact_entry(c: Dictionary, f: Dictionary, sim: RefCounted, npc: String) -> Dictionary:
	return {"id": f["id"], "title": "%s says" % CaseEngine.first(sim, npc), "text": f["text"], "kind": "testimony", "source": npc, "supports": f["supports"].duplicate(true), "day": int(sim.day)}


static func _reveal_ok(sim: RefCounted, det: RefCounted, npc: String, f: Dictionary) -> Dictionary:
	match String(f["reveal"]):
		"free":
			return {"ok": true}
		"rapport":
			var aff: float = sim.people[npc].affinity("player")
			if aff >= 10.0 or det.skill("charm") >= 4 or det.skill("empathy") >= 5:
				return {"ok": true}
			return {"ok": false, "text": "%s glances away. \"I don't know you well enough for that.\" [Charm 4, or earn their trust first]" % CaseEngine.first(sim, npc)}
		"pressure":
			var needs: Array = f.get("needs", [])
			var ok := not needs.is_empty()
			for n in needs:
				if not det.has(n):
					ok = false
			if ok or det.skill("authority") >= 6:
				return {"ok": true}
			return {"ok": false, "text": "%s goes quiet. They know something, and you have nothing to put in front of them yet." % CaseEngine.first(sim, npc)}
	return {"ok": true}


## Ask someone a question. Topics: alibi (about = who; "" means themselves), victim, suspects, saw.
static func ask(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, topic: String, about: String = "") -> Dictionary:
	var learned: Array = []
	var lines: Array = []
	var p: RefCounted = sim.people[npc]
	var victim: String = c["victim"]
	var minutes := 6
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
					lines.append("\"Home, in bed, like every night. Nobody to vouch for me but the cat.\"")
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
						var gate: Dictionary = _reveal_ok(sim, det, npc, f)
						if gate["ok"]:
							lines.append("\"%s\"" % f["text"])
							var e := _fact_entry(c, f, sim, npc)
							if det.learn(e):
								learned.append(e)
						else:
							lines.append(gate["text"])
				if not found:
					lines.append("\"I couldn't tell you where %s was. Not my business.\"" % CaseEngine.first(sim, about))
		"victim":
			var st: String = Relationship.stage(p.affinity(victim), p.trust(victim))
			lines.append("\"%s? %s.\"" % [CaseEngine.first(sim, victim), _opinion(st)])
			_facts_for(sim, c, det, npc, "victim", lines, learned)
		"suspects":
			var named := 0
			for sid in c["suspects"]:
				if sid != npc and p.affinity(sid) <= -20.0 and named < 2:
					lines.append("\"Between you and me, I don't trust %s.\"" % CaseEngine.name_of(sim, sid))
					named += 1
			_facts_for(sim, c, det, npc, "suspects", lines, learned)
			_facts_for(sim, c, det, npc, "owner", lines, learned)
			if lines.is_empty():
				lines.append("\"I wouldn't like to say. Everyone liked %s, mostly.\"" % CaseEngine.first(sim, victim))
		"saw":
			_facts_for(sim, c, det, npc, "saw", lines, learned)
			if lines.is_empty():
				lines.append("\"Asleep by ten. I didn't see or hear a thing.\"")
		"person":
			if about != "" and sim.people.has(about):
				var px: RefCounted = sim.people[about]
				var rel_word: String = Relationship.describe(sim, npc, about)
				lines.append("\"%s? %s, a %s. %s.\"" % [CaseEngine.first(sim, about), "My " + rel_word if rel_word in ["partner", "parent", "child", "sibling", "housemate"] else "We're " + rel_word, px.job, _habit(px)])
				if c.get("relatives", {}).get(about, []).has(npc) and c["profiles"].has(about) and c["profiles"][about]["lie"]:
					lines.append("\"They're a good person. Whatever you've heard, you've heard it wrong.\"")
				for fid in c["facts"]:
					var f2: Dictionary = c["facts"][fid]
					if f2["topic"] == "suspects" and f2["about"] == about and f2["knowers"].has(npc):
						lines.append("\"%s\"" % f2["text"])
						var e3 := _fact_entry(c, f2, sim, npc)
						if det.learn(e3):
							learned.append(e3)
	var text := "\n".join(lines)
	det.statements.append({"day": int(sim.day), "npc": npc, "topic": topic, "about": about, "text": text})
	if not learned.is_empty():
		det.gain_xp(12 * learned.size())
	# asking about the dead is hard on the living
	p.bump("player", -1.0 if topic in ["victim", "suspects"] else 0.0, 0.0)
	return {"text": text, "learned": learned, "minutes": minutes}


static func _habit(p: RefCounted) -> String:
	return "%s. %s" % [String(p.quirk).capitalize() if p.quirk != "" else "Keeps to routine", ("Spends spare time " + p.hobby) if p.hobby != "" else "Not much of a hobbyist"]


static func _opinion(stage: String) -> String:
	match stage:
		"best friend", "close friend": return "One of the best. I can't believe it"
		"friend": return "A good neighbour. A good person"
		"acquaintance": return "I knew them to nod to. Kept themselves to themselves"
		"stranger": return "I barely knew them"
		"on bad terms", "rival": return "We didn't get on, I won't lie. I wouldn't wish this on them"
		"enemy": return "I won't pretend to be sorry. But I didn't do it"
	return "I knew them"


static func _facts_for(sim: RefCounted, c: Dictionary, det: RefCounted, npc: String, topic: String, lines: Array, learned: Array) -> void:
	for fid in c["facts"]:
		var f: Dictionary = c["facts"][fid]
		if f["topic"] != topic or not f["knowers"].has(npc):
			continue
		var gate: Dictionary = _reveal_ok(sim, det, npc, f)
		if gate["ok"]:
			lines.append("\"%s\"" % f["text"])
			var e := _fact_entry(c, f, sim, npc)
			if det.learn(e):
				learned.append(e)
		else:
			lines.append(gate["text"])


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
			det.statements.append({"day": int(sim.day), "npc": npc, "topic": "present", "about": "", "text": text})
			if det.check("empathy", 3) == "pass":
				text += " [Empathy] They're lying. That frightened them."
		else:
			text = "\"That isn't anything I know.\""
	elif entry_id == "f_h1_seen" and c["profiles"].has(npc) and c["profiles"][npc].get("alibi", "") == "secret":
		var f2: Dictionary = c["facts"]["f_h1_secret"]
		var e2 := _fact_entry(c, f2, sim, npc)
		if det.learn(e2):
			learned.append(e2)
		text = "\"%s\"" % f2["text"]
		sim.people[npc].bump("player", -4.0, 0.0)
	elif _cover_cracks(c, npc, entry_id, det):
		var target: String = _covered(c, npc)
		var tname := CaseEngine.first(sim, target)
		var ent := {"id": "cover_" + npc, "title": "%s's cover breaks" % CaseEngine.first(sim, npc), "text": "%s admits it: %s was not home that night. They went out and came back late. They begged you not to say they told you." % [CaseEngine.first(sim, npc), tname],
			"kind": "testimony", "source": npc, "supports": [{"cat": "opportunity", "about": target, "strength": 2}] if target == k else [], "day": int(sim.day)}
		if det.learn(ent):
			learned.append(ent)
		text = "%s looks at the footage, then at the floor. \"...He went out. I lied. I'm sorry.\"" % CaseEngine.first(sim, npc)
		sim.people[npc].bump("player", -3.0, 0.0)
	elif npc == k and entry_id in ["c_phone", "c_door", "f_kn_saw", "f_vn_saw"]:
		text = "%s's jaw sets. \"Anyone could say that. Anyone could have called from my number.\"" % CaseEngine.first(sim, k)
		det.add_stress(2.0)
	else:
		text = "\"I don't know what you want me to say about that.\""
	det.statements.append({"day": int(sim.day), "npc": npc, "topic": "present", "about": entry_id, "text": text})
	return {"text": text, "learned": learned, "minutes": 5}


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
	for sup in e.get("supports", []):
		if sup["about"] == sid and sup["cat"] in ["opportunity", "link"] and e.get("kind", "") in ["cctv", "testimony"]:
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
	det.lab.append({"clue": clue_id, "ready_day": int(sim.day) + 1})
	return {"text": "Bagged and sent to the lab. Results tomorrow morning.", "minutes": 15}


## Results that are ready by `day` become notebook entries.
static func lab_results(sim: RefCounted, c: Dictionary, det: RefCounted, day: int) -> Array:
	var out: Array = Prints.compare_results(sim, c, det, day)
	var remaining: Array = []
	for l in det.lab:
		if l.get("print", "") != "":
			remaining.append(l)
		elif int(l["ready_day"]) <= day and c["lab"].has(l["clue"]):
			var r: Dictionary = c["lab"][l["clue"]]
			var e := {"id": "lab_" + l["clue"], "title": "Lab report", "text": r["text"], "kind": "lab", "source": "lab", "supports": r["supports"].duplicate(true), "day": day}
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
## Weigh an accusation against what the notebook can prove. Returns {verdict, score, parts, text}.
static func judge(sim: RefCounted, c: Dictionary, det: RefCounted, culprit: String, motive: String, method: String) -> Dictionary:
	var pr: Dictionary = det.proof_against(culprit)
	var cats := 0
	var total := 0
	for k in ["opportunity", "means", "motive", "link"]:
		if int(pr[k]) > 0:
			cats += 1
		total += int(pr[k])
	var right_person: bool = culprit == c["killer"]
	var right_motive: bool = motive == c["motive"]
	var right_method: bool = method == c["method"]
	var enough: bool = cats >= 3 and (int(pr["opportunity"]) > 0 or int(pr["link"]) > 0) and total >= 6
	var verdict := ""
	var text := ""
	if right_person and enough:
		verdict = "convicted"
		text = "%s breaks. The evidence holds, line by line. %s." % [CaseEngine.name_of(sim, culprit), _confession(sim, c, right_motive)]
	elif right_person and cats >= 2:
		verdict = "released"
		text = "It's the right person, but the case has holes a good lawyer walks through. %s is released pending trial, and knows you know." % CaseEngine.name_of(sim, culprit)
	elif right_person:
		verdict = "insufficient"
		text = "You name the killer, and you cannot prove a word of it. The Sheriff will not let you arrest on a hunch."
	else:
		verdict = "wrong"
		text = "%s did not do this. %s. The town will not forget that you said so." % [CaseEngine.name_of(sim, culprit), _innocence(sim, c, culprit)]
	var score := 0
	score += 40 if right_person else 0
	score += 15 if right_motive else 0
	score += 15 if right_method else 0
	score += mini(cats * 7, 30)
	return {"verdict": verdict, "score": score, "text": text, "cats": cats, "total": total, "right_person": right_person, "right_motive": right_motive, "right_method": right_method, "enough": enough}


static func _confession(sim: RefCounted, c: Dictionary, right_motive: bool) -> String:
	return "It was %s: %s. %s" % [c["motive"], c["motive_thing"], "You had it exactly right." if right_motive else "Your theory of why was wrong, but the truth is the same."]


static func _innocence(sim: RefCounted, c: Dictionary, id: String) -> String:
	var pr: Dictionary = c["profiles"].get(id, {})
	match String(pr.get("alibi", "")):
		"verified": return "They were %s all night, and half the town can say so" % "somewhere else"
		"secret": return "They had a secret to keep, which is not the same as a crime"
		"weak": return "They have no alibi, and no reason either"
	return "They were nowhere near it"


## What happens in the town as a result.
static func apply_outcome(sim: RefCounted, c: Dictionary, det: RefCounted, res: Dictionary, culprit: String) -> void:
	match String(res["verdict"]):
		"convicted":
			var pk: RefCounted = sim.people[c["killer"]]
			pk.taken = true
			pk.location = ""
			sim.log_event("arrest", c["killer"], "%s was arrested for the murder of %s." % [pk.display, CaseEngine.name_of(sim, c["victim"])])
			det.reputation["sheriff"] = int(det.reputation["sheriff"]) + 10
			det.reputation["town"] = int(det.reputation["town"]) + 5
			det.cases_solved += 1
			det.gain_xp(150)
			det.add_stress(-25.0)
			c["status"] = "solved"
		"released":
			c["status"] = "open"
			c["alerted"] = true
			det.gain_xp(40)
			det.add_stress(10.0)
		"insufficient":
			det.add_stress(6.0)
		"wrong":
			var pa: RefCounted = sim.people[culprit]
			pa.needs["comfort"] = clampf(float(pa.needs["comfort"]) - 35.0, 0.0, 100.0)
			pa.needs["restless"] = clampf(float(pa.needs["restless"]) + 30.0, 0.0, 100.0)
			for id in sim.order:
				if id != culprit and sim.people[id].rel.has(culprit):
					sim.people[id].bump(culprit, -6.0, -4.0)
			sim.seed_rumor(culprit, "The detective dragged %s in for the murder." % pa.display, false, "player", 3, 80.0)
			det.reputation["sheriff"] = int(det.reputation["sheriff"]) - 8
			det.reputation["town"] = int(det.reputation["town"]) - 6
			det.cases_failed += 1
			det.add_stress(20.0)
			if not c.has("wrong"):
				c["wrong"] = []
			c["wrong"].append(culprit)
