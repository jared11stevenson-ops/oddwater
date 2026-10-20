extends RefCounted
## The long road from suspicion to a cell. Arrest needs probable cause. The formal interrogation can produce a true confession,
## a refusal, or (under hours of pressure) a false one. The trial weighs what survives the defence: unreliable prints, uncalibrated
## cameras, a confession missing the held-back detail, and every suspect you never cleared. The jail keeps the convicted, and the
## innocent you got wrong.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Brief = preload("res://scripts/sim/brief.gd")

const TYPES := {"grudge": "organised", "money": "calculating", "family": "remorseful", "silence": "secretive", "passion": "volatile"}
const LORE := [
	"The lake level has not changed in sixty-three years. They measure it every morning, and they write the same number down.",
	"There's a bell you only hear at 4:12. The old ones don't ask what it is. They just close the window.",
	"Whatever you think this town is for, you have it backwards. It is not here to keep people in. It is here to keep something out.",
	"Ask the pastor about the hymn that isn't in the book. Then ask why the book has a gap where it should be."]


# =========================================================================== arrest and interrogation
static func probable_cause(det: RefCounted, target: String) -> bool:
	var pr: Dictionary = det.proof_against(target)
	var cats := 0
	var total := 0
	for k in ["opportunity", "means", "motive", "link"]:
		if int(pr[k]) > 0:
			cats += 1
		total += int(pr[k])
	return cats >= 2 and total >= 4 and int(pr["exonerate"]) < 3


## Arrest someone. Without probable cause the arrest is thrown out and it costs you.
static func arrest(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, target: String) -> Dictionary:
	if st.get("custody", "") != "":
		return {"ok": false, "text": "You already have someone in custody."}
	if not probable_cause(det, target):
		det.reputation["sheriff"] = int(det.reputation["sheriff"]) - 5
		det.add_stress(8.0)
		sim.people[target].bump("player", -20.0, -20.0)
		return {"ok": false, "text": "You can't arrest %s on a hunch. The Sheriff reminds you what probable cause means, and %s will not forget you tried." % [CaseEngine.name_of(sim, target), CaseEngine.first(sim, target)]}
	st["custody"] = target
	st["arrest_day"] = int(sim.day)
	st["trial_day"] = int(sim.day) + 3
	st["sess"] = {"rapport": 0.0, "resistance": 60.0 if target == c["killer"] else 45.0, "fatigue": 0.0, "sessions": 0, "pressure": 0}
	return {"ok": true, "text": "%s is in custody. Arraignment is tomorrow; the trial is set for day %d. You have until then." % [CaseEngine.name_of(sim, target), st["trial_day"]]}


## One session in the interview room. Approaches: rapport, evidence, pressure.
static func interrogate(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, approach: String) -> Dictionary:
	var t: String = st.get("custody", "")
	if t == "":
		return {"text": "Nobody is in custody.", "minutes": 0, "learned": []}
	var ss: Dictionary = st["sess"]
	var guilty: bool = t == c["killer"]
	var learned: Array = []
	var name := CaseEngine.first(sim, t)
	ss["sessions"] = int(ss["sessions"]) + 1
	var text := ""
	match approach:
		"rapport":
			ss["rapport"] = float(ss["rapport"]) + 15.0
			ss["resistance"] = float(ss["resistance"]) - 5.0
			ss["fatigue"] = maxf(float(ss["fatigue"]) - 5.0, 0.0)
			text = "You let %s talk. About the weather, the dog, the job. It takes forty minutes before the guard goes quiet. %s is a little less afraid of you." % [name, name]
		"evidence":
			var pr: Dictionary = det.proof_against(t)
			var w := float(pr["opportunity"] + pr["means"] + pr["motive"] + pr["link"])
			ss["resistance"] = float(ss["resistance"]) - (w * 4.0 if guilty else w * 1.0)
			ss["fatigue"] = float(ss["fatigue"]) + 10.0
			text = "You lay it out, piece by piece. %s watches the table the whole time." % name
		"pressure":
			ss["resistance"] = float(ss["resistance"]) - 12.0
			ss["fatigue"] = float(ss["fatigue"]) + 25.0
			ss["rapport"] = float(ss["rapport"]) - 15.0
			ss["pressure"] = int(ss["pressure"]) + 1
			text = "You press. You keep pressing. The room is hot, the clock is slow, and %s has not slept." % name
	# outcomes
	if guilty and float(ss["resistance"]) <= 0.0 and not det.has("confession_" + t):
		var e := {"id": "confession_" + t, "title": "Confession: %s" % CaseEngine.first(sim, t), "kind": "confession",
			"text": "%s breaks. \"I went round after midnight. We argued about %s. I didn't mean... %s.\" Then, quietly: \"%s.\"" % [CaseEngine.name_of(sim, t), c["motive_thing"], "it happened so fast", c["held_back"]],
			"source": t, "supports": [{"cat": "opportunity", "about": t, "strength": 3}, {"cat": "motive", "about": t, "strength": 2}, {"cat": "means", "about": t, "strength": 2}], "day": int(sim.day), "has_detail": true}
		if det.learn(e):
			learned.append(e)
		text += "\n\nAnd then it comes. A true confession, with the one detail you never told anyone."
	elif not guilty and float(ss["fatigue"]) >= 75.0 and int(ss["pressure"]) >= 2 and not det.has("confession_" + t):
		var e2 := {"id": "confession_" + t, "title": "Confession: %s" % CaseEngine.first(sim, t), "kind": "confession",
			"text": "%s breaks, exhausted. \"Fine. I did it. Whatever you want me to say. I went round, I... I don't remember. I just want to go home.\"" % CaseEngine.name_of(sim, t),
			"source": t, "supports": [{"cat": "opportunity", "about": t, "strength": 3}], "day": int(sim.day), "has_detail": false, "unreliable": true}
		if det.learn(e2):
			learned.append(e2)
		text += "\n\nA confession. It arrives at the exact moment %s runs out of strength. You notice that it has no detail in it you didn't hand them yourself." % name
	elif float(ss["rapport"]) <= -30.0:
		text += "\n\n\"I want a lawyer.\" The session is over."
	return {"text": text, "minutes": 60, "learned": learned}


# =========================================================================== trial
## The jury's confidence, with the defence's attacks. Returns {confidence, attacks: [{text, delta}], verdict, sentence, wrongful}.
static func trial(sim: RefCounted, c: Dictionary, det: RefCounted, target: String) -> Dictionary:
	var pr: Dictionary = det.proof_against(target)
	var total := mini(int(pr["opportunity"] + pr["means"] + pr["motive"] + pr["link"]), 14)
	var cats := 0
	for k in ["opportunity", "means", "motive", "link"]:
		if int(pr[k]) > 0:
			cats += 1
	var conf := 20.0 + total * 4.5 + cats * 4.0
	var attacks: Array = []
	var add := func(t: String, d: float) -> void:
		attacks.append({"text": t, "delta": d})
		conf += d
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		var about: bool = false
		for sup in e.get("supports", []):
			if sup["about"] == target:
				about = true
		if not about:
			continue
		if e.get("unreliable", false) and e.get("kind", "") == "confession":
			add.call("The defence: \"This confession contains nothing only the killer would know. My client was exhausted and frightened.\"", -30.0)
		elif e.get("unreliable", false):
			add.call("The defence: \"A partial print. Seven points. It is 'consistent with' half the town.\"", -8.0)
		if e.get("kind", "") == "cctv" and not e.get("calibrated", false):
			add.call("The defence: \"The camera's clock was never checked. These times mean nothing.\"", -6.0)
		if e.get("kind", "") == "confession" and e.get("has_detail", false):
			add.call("The prosecution: the confession includes a detail that was never made public. The room goes quiet.", 18.0)
		if e.get("kind", "") == "lab" and not e.get("unreliable", false) and e.get("text", "").begins_with("Conclusive"):
			add.call("The prosecution: a conclusive print, verified by a second examiner.", 6.0)
	# the other suspects: any you never cleared become the defence's alternative
	for s in c["suspects"]:
		if s == target:
			continue
		if int(det.proof_against(s)["exonerate"]) < 3:
			add.call("The defence points across the room: \"%s had a motive and no alibi, and nobody ever ruled them out.\"" % CaseEngine.name_of(sim, s), -5.0)
	var look: String = c.get("lookalike", "")
	if look != "" and det.order.any(func(e): return String(e).begins_with("cmp_") and String(e).ends_with(look) and det.known[e].get("unreliable", false)) and target != look:
		add.call("The defence: \"A print comparison pointed at someone else entirely. Where was that explored?\"", -6.0)
	conf = clampf(conf, 0.0, 100.0)
	var verdict := "guilty" if conf >= 70.0 else ("hung" if conf >= 45.0 else "not guilty")
	var guilty_truth: bool = target == c["killer"]
	return {"confidence": conf, "attacks": attacks, "verdict": verdict, "sentence": 25 if verdict == "guilty" else 0, "wrongful": verdict == "guilty" and not guilty_truth, "target": target}


## Apply a verdict: guilty goes to jail; not guilty goes home (a guilty one freed is dangerous).
static func conclude(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, jail: Array, res: Dictionary) -> void:
	var t: String = res["target"]
	var p: RefCounted = sim.people[t]
	st["custody"] = ""
	match String(res["verdict"]):
		"guilty":
			p.jailed = true
			p.location = ""
			var inmate := {"id": t, "case": c["id"], "guilty": t == c["killer"], "sentence": res["sentence"], "type": TYPES[c["motive"]], "rapport": 0.0, "told": [], "day": int(sim.day), "freed": false}
			jail.append(inmate)
			if t == c["killer"]:
				c["status"] = "solved"
				det.cases_solved += 1
				det.reputation["sheriff"] = int(det.reputation["sheriff"]) + 10
				det.gain_xp(150)
			else:
				det.cases_failed += 1
				det.reputation["town"] = int(det.reputation["town"]) - 8
				det.add_stress(25.0)
		"hung":
			st["custody"] = t
			st["trial_day"] = int(sim.day) + 3
			det.add_stress(6.0)
		_:
			p.needs["comfort"] = clampf(float(p.needs["comfort"]) - 15.0, 0.0, 100.0)
			if t == c["killer"]:
				c["alerted"] = true
				det.add_stress(15.0)
			else:
				det.cases_failed += 1


# =========================================================================== the jail
static func visiting_hours(h: float) -> bool:
	return h >= 10.0 and h < 16.0


## Sit across the glass from someone you put away. Rapport unlocks what they will say.
static func visit(sim: RefCounted, c: Dictionary, det: RefCounted, inmate: Dictionary, topic: String) -> Dictionary:
	var name := CaseEngine.first(sim, inmate["id"])
	var text := ""
	match topic:
		"talk":
			inmate["rapport"] = float(inmate["rapport"]) + 12.0
			text = "%s talks about the food, the guard with the bad knee, the letters nobody sends. They say your name once, then pretend they didn't." % name
		"crime":
			if inmate["guilty"]:
				if float(inmate["rapport"]) >= 20.0:
					text = "\"You want to know why? %s. That's all. It sounds smaller every year.\" They look at their hands. \"%s.\"" % [c["motive_thing"], c["held_back"]]
				else:
					text = "%s will not say. Not yet. \"Ask me when I know you're not just writing it down for a book.\"" % name
			else:
				text = "\"I didn't do it. I've said it so many times it has stopped sounding like words.\" %s is telling the truth, and you know it, and you are the one who put them here." % name
		"town":
			if float(inmate["rapport"]) >= 12.0 + 10.0 * inmate["told"].size():
				var i: int = inmate["told"].size()
				if i < LORE.size():
					inmate["told"].append(i)
					text = "\"All right. One thing, for free. %s\"" % LORE[(absi(hash(inmate["id"])) + i) % LORE.size()]
					var e := {"id": "lore_%s_%d" % [inmate["id"], i], "title": "From %s, in jail" % name, "text": LORE[(absi(hash(inmate["id"])) + i) % LORE.size()], "kind": "lore", "source": inmate["id"], "supports": [], "day": int(sim.day)}
					det.learn(e)
					det.gain_xp(25)
				else:
					text = "%s shrugs. \"That's everything I've got.\"" % name
			else:
				text = "%s leans back. \"Come see me more often. I don't talk to strangers.\"" % name
		"profile":
			text = "A %s mind, you think: %s. You write it down. Whatever this one taught you, you'll use it on the next." % [inmate["type"], "patient, tidy, always three steps ahead" if inmate["type"] == "organised" else "everything has a price" if inmate["type"] == "calculating" else "heavy with it, and sorry" if inmate["type"] == "remorseful" else "guarded to the last" if inmate["type"] == "secretive" else "fast to flare, and to regret"]
			det.add_stress(2.0)
			inmate["rapport"] = float(inmate["rapport"]) + 5.0
	return {"text": text, "minutes": 30}


## Free someone you wrongly convicted, if you can now prove who really did it.
static func appeal(sim: RefCounted, c: Dictionary, det: RefCounted, jail: Array, inmate: Dictionary) -> Dictionary:
	if inmate["guilty"]:
		return {"ok": false, "text": "There is nothing to appeal. They did it."}
	var pr: Dictionary = det.proof_against(c["killer"])
	var cats := 0
	var total := 0
	for k in ["opportunity", "means", "motive", "link"]:
		if int(pr[k]) > 0:
			cats += 1
		total += int(pr[k])
	if cats < 3 or total < 6:
		return {"ok": false, "text": "The judge will not reopen it on a feeling. Find who really did this, and prove it."}
	sim.people[inmate["id"]].jailed = false
	sim.people[inmate["id"]].location = sim.people[inmate["id"]].home
	inmate["freed"] = true
	jail.erase(inmate)
	det.reputation["town"] = int(det.reputation["town"]) + 6
	det.add_stress(-15.0)
	c["alerted"] = true
	return {"ok": true, "text": "%s walks out into the rain. They don't thank you. They don't have to. The case is open again, and the real killer is watching." % CaseEngine.name_of(sim, inmate["id"])}
