extends RefCounted
## The long road from suspicion to a cell. Arrest needs probable cause. The formal interrogation can produce a true confession,
## a refusal, or (under hours of pressure) a false one. The trial weighs what survives the defence: unreliable prints, uncalibrated
## cameras, a confession missing the held-back detail, and every suspect you never cleared. The jail keeps the convicted, and the
## innocent you got wrong.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Data = preload("res://scripts/core/data.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Confessor = preload("res://scripts/detective/confessor.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")

const TYPES := {"grudge": "organised", "money": "calculating", "family": "remorseful", "silence": "secretive", "passion": "volatile"}
const LORE := [
	"The lake level has not changed in sixty-three years. They measure it every morning, and they write the same number down.",
	"There's a bell you only hear at 4:12. The old ones don't ask what it is. They just close the window.",
	"Whatever you think this town is for, you have it backwards. It is not here to keep people in. It is here to keep something out.",
	"Ask the pastor about the hymn that isn't in the book. Then ask why the book has a gap where it should be.",
	"The old jury never went home. That is the part nobody says. They went down to the water in a line, and the line is still there on the nights the fog comes in.",
	"Every house in Little Mercy has a window that faces the lake and is never opened. Ask whoever built yours why.",
	"You have noticed that no one says goodbye here. It isn't manners. Goodbye is a word that gets answered."]

const APPROACH := {
	"rapport": [
		"You let {n} talk. About the weather, the dog, the job. It takes forty minutes before the guard goes quiet. {n} is a little less afraid of you.",
		"You bring two coffees and say nothing about the case. {n} wraps both hands round a cup and starts, haltingly, on the winter the lake froze.",
		"You ask about ordinary things: what {n} had for breakfast, who feeds the cat. {n} answers each slowly, testing it for a trap, and finds none.",
		"You sit with {n} until the clock has gone round once. Neither of you mentions the dead. It is the nearest thing to a conversation you have had all week."],
	"evidence": [
		"You lay it out, piece by piece. {n} watches the table the whole time.",
		"You slide the first page across, then the second. {n} reads each one twice, the way people read a bill.",
		"You put the pieces down in the order you found them. {n} follows your finger to each, and flinches only once, and not where you expected.",
		"The file lies open between you. You do not touch it. You let {n} see how thick it has become."],
	"pressure": [
		"You press. You keep pressing. The room is hot, the clock is slow, and {n} has not slept.",
		"You come back to the same three questions, asked in a different order each time. {n}'s answers begin to arrive a half-second before the questions finish.",
		"The lights stay on. The coffee stops coming. You ask again, and again, and {n} begins to answer questions you have not asked.",
		"You say the dead person's name in every sentence. By the sixth {n} has stopped flinching, and that is worse."]}

const INNOCENT_TELLS := [
	"{n} keeps repeating one true thing in exactly the same words, the way a person says a prayer they half believe.",
	"{n} is frightened, but of the room, and of you, and not of anything you say about the night. It is a different kind of fear.",
	"{n} answers before you finish, and the answer is always the same: plain, tired, and not very clever. A liar would be cleverer.",
	"{n} asks twice, in different words, whether they can go home. It is not what a guilty person asks. A guilty person asks how long."]



# =========================================================================== arrest and interrogation
static func probable_cause(det: RefCounted, target: String) -> bool:
	var pr: Dictionary = det.proof_against(target)
	var tl: Dictionary = Reasoning.tally(pr)
	return int(tl["cats"]) >= 2 and int(tl["total"]) >= 4 and int(pr["exonerate"]) < 3


## Arrest someone. Without probable cause the arrest is thrown out and it costs you.
static func arrest(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, target: String) -> Dictionary:
	if st.get("custody", "") != "":
		return {"ok": false, "text": "You already have someone in custody."}
	if bool(Confessor.entry_for(det, target).get("tested", false)):
		return {"ok": false, "text": "%s's confession has already failed the held-back test. There is nothing to arrest anyone for." % CaseEngine.name_of(sim, target)}
	if not probable_cause(det, target):
		Reputation.apply(det, "failed_arrest", int(sim.day))
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
			text = _round_text("rapport", int(ss["sessions"]), name)
		"evidence":
			var pr: Dictionary = det.proof_against(t)
			var w := float(pr["opportunity"] + pr["means"] + pr["motive"] + pr["link"])
			ss["resistance"] = float(ss["resistance"]) - (w * 4.0 if guilty else w * 1.0)
			ss["fatigue"] = float(ss["fatigue"]) + 10.0
			text = _round_text("evidence", int(ss["sessions"]), name)
		"pressure":
			ss["resistance"] = float(ss["resistance"]) - 12.0
			ss["fatigue"] = float(ss["fatigue"]) + 25.0
			ss["rapport"] = float(ss["rapport"]) - 15.0
			ss["pressure"] = int(ss["pressure"]) + 1
			text = _round_text("pressure", int(ss["sessions"]), name)
	# what the face does, and what a patient killer says back
	text += "\n\n" + _tell_and_voice(sim, c, det, t, guilty, int(ss["sessions"]), learned)
	# a confessor who is not the killer: the interview room is where the story meets the scene
	if Confessor.untested(det, t):
		var tt: Dictionary = Confessor.test(sim, c, det, t)
		text += "\n\n" + String(tt["text"])
		for le in tt["learned"]:
			learned.append(le)
	# outcomes
	if guilty and float(ss["resistance"]) <= 0.0 and not det.has("confession_" + t):
		var e := {"id": "confession_" + t, "title": "Confession: %s" % CaseEngine.first(sim, t), "kind": "confession",
			"text": "%s breaks. \"I went round after midnight. We argued about %s. I didn't mean... %s.\" Then, quietly: \"%s.\"" % [CaseEngine.name_of(sim, t), CaseEngine.thing_about(c["motive_thing"]), "it happened so fast", c["held_back"]],
			"source": t, "day": int(sim.day)}
		e["claims"] = Claims.emit(c, [Claims.make("said", t, "confessed", "", -1.0, String(c["held_back"]), 0.95, "true")], t, String(e["text"]))
		if det.learn(e):
			learned.append(e)
		text += "\n\nAnd then it comes. A true confession, with the one detail you never told anyone."
	elif not guilty and float(ss["fatigue"]) >= 75.0 and int(ss["pressure"]) >= 2 and not det.has("confession_" + t):
		var e2 := {"id": "confession_" + t, "title": "Confession: %s" % CaseEngine.first(sim, t), "kind": "confession",
			"text": "%s breaks, exhausted. \"Fine. I did it. Whatever you want me to say. I went round, I... I don't remember. I just want to go home.\"" % CaseEngine.name_of(sim, t),
			"source": t, "day": int(sim.day)}
		e2["claims"] = Claims.emit(c, [Claims.make("said", t, "confessed", "", -1.0, "", 0.7, "false")], t, String(e2["text"]))
		if det.learn(e2):
			learned.append(e2)
		text += "\n\nA confession. It arrives at the exact moment %s runs out of strength. You notice that it has no detail in it you didn't hand them yourself." % name
	elif float(ss["rapport"]) <= -30.0:
		text += "\n\n\"I want a lawyer.\" The session is over."
	return {"text": text, "minutes": 60, "learned": learned}


static func _round_text(approach: String, round_n: int, name: String) -> String:
	var bank: Array = APPROACH[approach]
	return String(bank[(maxi(round_n, 1) - 1) % bank.size()]).replace("{n}", name)


## The tell (a small thing the body does) and, from the second session, the killer's own philosophy answering back. Guilty and innocent
## people sit differently. The tell goes in the notebook so you can weigh it later; it proves nothing and it is not meant to.
static func _tell_and_voice(sim: RefCounted, c: Dictionary, det: RefCounted, t: String, guilty: bool, round_n: int, learned: Array) -> String:
	var h: Dictionary = Prose.json("detective/horror.json")
	var name := CaseEngine.first(sim, t)
	var type: String = TYPES[c["motive"]]
	var tell: String
	if guilty:
		var tl: Array = h["tells"][type]
		tell = String(tl[(round_n - 1) % tl.size()]) % name
	else:
		tell = String(INNOCENT_TELLS[(round_n + absi(hash(t))) % INNOCENT_TELLS.size()]).replace("{n}", name)
	var out := tell
	var e := {"id": "tell_%s_%d" % [t, round_n], "title": "Interview %d: %s" % [round_n, name], "kind": "testimony", "source": t, "day": int(sim.day), "text": tell}
	e["claims"] = Claims.emit(c, [Claims.make("seen", t, "demeanour", "", -1.0, "", 0.6)], t, tell)
	if det.learn(e):
		learned.append(e)
	if guilty and round_n >= 2:
		var ph: Array = h["philosophy"][type]
		var line: String = ph[(round_n - 2) % ph.size()]
		out += "\n\n%s says, without being asked: %s" % [name, line]
		var e2 := {"id": "view_%s_%d" % [t, round_n], "title": "%s argues back" % name, "kind": "testimony", "source": t, "day": int(sim.day), "text": line}
		e2["claims"] = Claims.emit(c, [Claims.make("said", t, "demeanour", "", -1.0, "", 0.6)], t, line)
		if det.learn(e2):
			learned.append(e2)
	return out


# =========================================================================== trial
## The jury's confidence, with the defence's attacks. The weight of the case comes from the notebook (Reasoning); what the court adds is the
## truth about each claim: a witness who was wrong, a lie, a clock that was out. A mistaken witness can sink a right case and a false confession
## can convict the wrong person. Returns {confidence, attacks: [{text, delta}], verdict, sentence, wrongful}.
static func trial(sim: RefCounted, c: Dictionary, det: RefCounted, target: String) -> Dictionary:
	var pr: Dictionary = det.proof_against(target)
	var tl: Dictionary = Reasoning.tally(pr)
	var total := mini(int(tl["total"]), 14)
	var cats: int = tl["cats"]
	var conf := 28.0 + total * 5.0 + cats * 4.0   # three solid categories and six points of proof is a case a jury convicts on (70); judge() asks this same function
	var attacks: Array = []
	var add := func(t: String, d: float) -> void:
		attacks.append({"text": t, "delta": d})      # (a lambda sees conf by value: the deltas are summed after the loop)
	var partial_other := false
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		var mine: Array = []
		for cl in e.get("claims", []):
			if cl.get("subject", "") == target:
				mine.append(cl)
		var about_other_print := false
		for cl in e.get("claims", []):
			if String(cl.get("predicate", "")) == "print_match" and cl.get("subject", "") != target and float(cl.get("certainty", 1.0)) < 0.7:
				about_other_print = true
		if about_other_print and String(eid).begins_with("cmp_") and not partial_other:
			partial_other = true
			add.call("The defence: \"A print comparison pointed at someone else entirely. Where was that explored?\"", -6.0)
		if mine.is_empty():
			continue
		if e.get("kind", "") == "cctv" and not e.get("calibrated", false):
			add.call("The defence: \"The camera's clock was never checked. These times mean nothing.\"", -6.0)
		for cl in mine:
			var tag: String = Claims.tag_of(c, cl)
			var pred: String = String(cl.get("predicate", ""))
			var cert: float = float(cl.get("certainty", 1.0))
			if pred == "confessed_story":
				if tag == "false" and not e.get("tested", false):
					add.call("The prosecution: a signed, voluntary confession, with the hour, the weapon and the wound. The jury looks at the accused and does not look away.", 14.0)
			elif pred == "confession_disproved":
				add.call("The defence: \"This confession contains nothing only the killer would know. My client was exhausted and frightened.\"", -30.0)
			elif pred == "confessed":
				if String(cl.get("item", "")) != "" and tag == "true":
					add.call("The prosecution: the confession includes a detail that was never made public. The room goes quiet.", 18.0)
				elif tag == "false":
					add.call("The defence: \"This confession contains nothing only the killer would know. My client was exhausted and frightened.\"", -30.0)
			elif pred == "print_match" and cert < 0.7:
				add.call("The defence: \"A partial print. Seven points. It is 'consistent with' half the town.\"", -8.0)
			elif tag == "false" and Reasoning.RULES.has(pred):
				add.call("The defence takes the witness apart: a grudge, a bad memory, a story that does not hold. The jury stops listening to that part.", -12.0)
			elif tag == "misleading" and Reasoning.RULES.has(pred) and e.get("kind", "") != "cctv":
				add.call("The defence: \"A mistake of the hour, of the place, of the person. Everyone in this room has made one.\"", -8.0)
		if e.get("kind", "") == "lab" and String(e.get("text", "")).begins_with("Conclusive") and not mine.is_empty() and Claims.tag_of(c, mine[0]) == "true":
			add.call("The prosecution: a conclusive print, verified by a second examiner.", 6.0)
	# the other names in the notebook: any you never cleared become the defence's alternative
	for s in Reasoning.people_named(det.known):
		if s == target or s == "player" or s == String(c["victim"]) or s == String(c["found_by"]):
			continue
		var ps: Dictionary = det.proof_against(s)
		if int(ps["exonerate"]) < 3 and int(Reasoning.tally(ps)["total"]) >= 2:
			add.call("The defence points across the room: \"%s had a motive and no alibi, and nobody ever ruled them out.\"" % CaseEngine.name_of(sim, s), -5.0)
	var target_confessed := false
	for eid in det.order:
		for cl in det.known[eid].get("claims", []):
			if cl.get("subject", "") == target and String(cl.get("predicate", "")) in ["confessed_story", "confession_disproved"]:
				target_confessed = true
	if not target_confessed:
		for eid in det.order:
			var ce: Dictionary = det.known[eid]
			for cl in ce.get("claims", []):
				if String(cl.get("predicate", "")) == "confessed_story" and not ce.get("tested", false) and cl.get("subject", "") != target:
					add.call("The defence: \"%s has confessed in writing. Why is my client in the dock and not them?\"" % CaseEngine.name_of(sim, String(cl["subject"])), -8.0)
	for a in attacks:
		conf += float(a["delta"])
	conf = clampf(conf, 0.0, 100.0)
	var verdict := "guilty" if conf >= 70.0 else ("hung" if conf >= 45.0 else "not guilty")
	var guilty_truth: bool = target == c["killer"]
	return {"confidence": conf, "attacks": attacks, "verdict": verdict, "sentence": 25 if verdict == "guilty" else 0, "wrongful": verdict == "guilty" and not guilty_truth, "target": target}


## Apply a verdict: guilty goes to jail; not guilty goes home (a guilty one freed is dangerous). Every cost goes through the one reputation ledger.
static func conclude(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, jail: Array, res: Dictionary) -> void:
	var t: String = res["target"]
	var p: RefCounted = sim.people[t]
	var day := int(sim.day)
	st["custody"] = ""
	match String(res["verdict"]):
		"guilty":
			p.jailed = true
			p.location = ""
			var inmate := {"id": t, "case": c["id"], "guilty": t == c["killer"], "sentence": res["sentence"], "type": TYPES[c["motive"]], "rapport": 0.0, "told": [], "day": day, "freed": false}
			jail.append(inmate)
			if t == c["killer"]:
				c["status"] = "solved"
				det.cases_solved += 1
				Reputation.apply(det, "convicted_killer", day)
				if _is_occult(c):
					Reputation.apply(det, "occult_solved", day)
				det.gain_xp(150)
				det.add_stress(-25.0)
			else:
				det.cases_failed += 1
				Reputation.apply(det, "wrongful_conviction", day)
				det.add_stress(25.0)
				if Confessor.is_false(c, t):
					c["false_conviction"] = t
					Reputation.apply(det, "false_confession_jailed", day)
		"hung":
			st["custody"] = t
			st["trial_day"] = day + 3
			Reputation.apply(det, "hung_jury", day)
			det.add_stress(6.0)
		_:
			p.needs["comfort"] = clampf(float(p.needs["comfort"]) - 15.0, 0.0, 100.0)
			if t == c["killer"]:
				c["alerted"] = true
				c["killer_alert"] = int(c.get("killer_alert", 0)) + 1
				Reputation.apply(det, "acquitted_guilty", day)
				det.add_stress(15.0)
			else:
				det.cases_failed += 1


## Was this an old-town case: a vigil, a stopped clock at 4:12?
static func _is_occult(c: Dictionary) -> bool:
	if String(c.get("held_back", "")).contains("4:12"):
		return true
	for id in c.get("profiles", {}):
		if c["profiles"][id].get("cult", false):
			return true
	return false


## The formal accusation as one coherent road: charge -> arrest -> interrogation -> trial -> a cell. `fast` runs it all in one sitting
## (a case that already holds up); otherwise the accused is held and the trial is set three days on. Returns the trial result, if one was
## held, plus the interview notes.
static func formal_charge(sim: RefCounted, c: Dictionary, det: RefCounted, st: Dictionary, jail: Array, culprit: String, right_theory: bool, fast: bool) -> Dictionary:
	var out := {"custody": true, "interview": "", "trial": {}, "learned": []}
	if st.get("custody", "") != "" and st["custody"] != culprit:
		st["custody"] = ""         # the one held before is let go: the charge has moved
	st["custody"] = culprit
	st["arrest_day"] = int(sim.day)
	st["trial_day"] = int(sim.day) if fast else int(sim.day) + 3
	var guilty: bool = culprit == c["killer"]
	st["sess"] = {"rapport": 0.0, "resistance": 60.0 if guilty else 45.0, "fatigue": 0.0, "sessions": 0, "pressure": 0}
	if right_theory:
		st["sess"]["resistance"] = float(st["sess"]["resistance"]) - 20.0     # laying the whole theory on the table counts
	var iv: Dictionary = interrogate(sim, c, det, st, "evidence")
	out["interview"] = iv["text"]
	out["learned"] = iv["learned"]
	if fast:
		var tr: Dictionary = trial(sim, c, det, culprit)
		conclude(sim, c, det, st, jail, tr)
		out["trial"] = tr
	return out


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
					text = "\"You want to know why? %s. That's all. It sounds smaller every year.\" They look at their hands. \"%s.\"" % [Prose.sentence(CaseEngine.thing_about(c["motive_thing"])), c["held_back"]]
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
					var e := {"id": "lore_%s_%d" % [inmate["id"], i], "title": "From %s, in jail" % name, "text": LORE[(absi(hash(inmate["id"])) + i) % LORE.size()], "kind": "lore", "source": inmate["id"], "day": int(sim.day)}
					e["claims"] = Claims.emit(c, [Claims.make("said", "", "lore")], String(inmate["id"]), String(e["text"]))
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
	var tl: Dictionary = Reasoning.tally(det.proof_against(c["killer"]))
	if int(tl["cats"]) < 3 or int(tl["total"]) < 6:
		return {"ok": false, "text": "The judge will not reopen it on a feeling. Find who really did this, and prove it."}
	sim.people[inmate["id"]].jailed = false
	sim.people[inmate["id"]].location = sim.people[inmate["id"]].home
	inmate["freed"] = true
	jail.erase(inmate)
	Reputation.apply(det, "appeal_win", int(sim.day))
	det.add_stress(-15.0)
	c["alerted"] = true
	return {"ok": true, "text": "%s walks out into the rain. They don't thank you. They don't have to. The case is open again, and the real killer is watching." % CaseEngine.name_of(sim, inmate["id"])}
