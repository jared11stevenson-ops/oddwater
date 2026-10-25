extends RefCounted
## Dread. Fear that is readable and fair. The detective's stress and the dark set a level (steady, uneasy, frayed, breaking). At high levels
## the notebook whispers lines that count real things you wrote, an intrusive thought offers a bad idea (and says what it costs), and the
## night can bring a real event: someone followed you, a note, a call with no voice, a lamp put out. Each is a notebook entry with claims
## you can check (a time, a place, the trace of a trade), never a random fright. A serial killer, or one who knows you are close, may write
## to you, and what you do about it changes the case.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const Informants = preload("res://scripts/detective/informants.gd")
const Brief = preload("res://scripts/sim/brief.gd")

const QUIET_AFTER := 2          # nights between events
const IDEAS := ["raw_search", "press", "name_first"]


static func _d() -> Dictionary:
	return Prose.json("detective/dread.json")


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


## 0 steady, 1 uneasy, 2 frayed, 3 breaking. The dark adds one.
static func level(det: RefCounted, hour: float = 12.0) -> int:
	var s: float = float(det.stress)
	var lv: int = 0 if s < 45.0 else (1 if s < 65.0 else (2 if s < 85.0 else 3))
	if hour >= 21.0 and lv >= 1:
		lv += 1
	return clampi(lv, 0, 3)


static func level_name(lv: int) -> String:
	return String(_d()["levels"][clampi(lv, 0, 3)])


static func state(det: RefCounted) -> Dictionary:
	if det.dread.is_empty():
		det.dread = {"last": -9, "intr_day": -1, "letters": 0, "quiet_until": -1, "late": -1, "events": []}
	return det.dread


# ------------------------------------------------------------------ the page whispers
## A line at the foot of the notebook when you are frayed. It counts real things in the book, so you can check it.
static func whisper(g: RefCounted) -> String:
	var lv: int = level(g.det, g.sim.hour_now())
	if lv < 2:
		return ""
	var d: Dictionary = _d()
	var named: Array = Reasoning.people_named(g.det.known)
	named = named.filter(func(x): return g.sim.people.has(x) and x != String(g.case.get("victim", "")) and x != "player")
	var who: String = String(named[0]) if not named.is_empty() else String(g.case.get("found_by", ""))
	var nm: String = CaseEngine.first(g.sim, who) if who != "" and g.sim.people.has(who) else "someone"
	var k := 0
	for e in g.det.known.values():
		if String(e.get("text", "")).contains(nm) or String(e.get("title", "")).contains(nm):
			k += 1
	var line: String = _pick(d["whisper"], "%s|%d|%d" % [g.case.get("id", ""), int(g.sim.day), g.det.order.size() / 4])
	return Prose.clean(line.replace("{n}", nm).replace("{k}", str(maxi(k, 1))).replace("{v}", CaseEngine.first(g.sim, String(g.case.get("victim", "")))))


# ------------------------------------------------------------------ the bad idea
## At high stress an intrusive thought may offer a bad idea. Returns {} or {idea, text, label, risk, who}. Nothing here knows the answer: the
## person it fixes on is whoever your own notebook weighs hardest, and the thought says honestly what taking it would cost.
static func intrusion(g: RefCounted) -> Dictionary:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	var lv: int = level(det, g.sim.hour_now())
	if lv < 2 or int(st["intr_day"]) == int(g.sim.day) or g.phase != "day":
		return {}
	var salt := "%s|intr|%d" % [g.case.get("id", ""), int(g.sim.day)]
	if absi(hash(salt)) % 100 >= (30 if lv == 2 else 55):
		return {}
	var best := ""
	var bt := -1
	for pid in g.persons_of_interest():
		var pr: Dictionary = det.proof_against(String(pid))
		var t: int = int(pr["opportunity"]) + int(pr["link"]) + int(pr["means"]) + int(pr["motive"]) - 2 * int(pr["exonerate"])
		if t > bt and String(pid) != String(g.case.get("found_by", "")):
			bt = t
			best = String(pid)
	if best == "":
		return {}
	var kinds: Array = IDEAS.duplicate()
	var idea: String = String(kinds[absi(hash(salt + "|k")) % kinds.size()])
	var d: Dictionary = _d()["ideas"][idea]
	var nm: String = CaseEngine.first(g.sim, best)
	return {"idea": idea, "who": best, "text": Prose.clean(_pick(d["text"], salt + idea).replace("{n}", nm)), "label": String(d["label"]).replace("{n}", nm), "risk": String(d["risk"]).replace("{n}", nm)}


static func dismiss(g: RefCounted) -> String:
	state(g.det)["intr_day"] = int(g.sim.day)
	g.det.add_stress(-1.0)
	return String(_d()["idea_dismiss"])


## Take the bad idea. Returns {text}. Each does what its label says, and costs what its risk says.
static func accept(g: RefCounted, idea: String, who: String) -> Dictionary:
	var det: RefCounted = g.det
	state(det)["intr_day"] = int(g.sim.day)
	if not g.sim.people.has(who):
		return {"text": ""}
	match idea:
		"raw_search":
			var r: Dictionary = g.examine(String(g.sim.people[who].home), "search_raw")
			det.add_stress(-4.0)
			Reputation.apply(det, "dirty_search", int(g.sim.day))
			return {"text": String(r["text"])}
		"press":
			var r2: Dictionary = g.ask(who, "alibi", "", "press")
			det.add_stress(-3.0)
			return {"text": String(r2["text"])}
		"name_first":
			var sh: Dictionary = det.sheet if not det.sheet.is_empty() else load("res://scripts/detective/sheet.gd").ensure(det)
			sh["who"] = who
			(sh["cites"] as Dictionary)["who"] = []
			det.add_stress(-5.0)
			return {"text": "You write %s's name on the sheet and the relief is immediate, like a held breath let out. You have cited nothing. It will not stay stamped." % CaseEngine.name_of(g.sim, who)}
	return {"text": ""}


# ------------------------------------------------------------------ the night
static func _actor(g: RefCounted, rnd: RandomNumberGenerator, killer_ok: bool) -> Dictionary:
	var c: Dictionary = g._truth
	var k: String = String(c.get("killer", ""))
	if killer_ok and g.sim.people.has(k) and g.sim.alive(g.sim.people[k]) and not g.sim.people[k].jailed:
		return {"id": k, "killer": true}
	var pool: Array = Informants.pool(g)
	if pool.is_empty():
		pool = g.sim.order.filter(func(x): return x != "player" and x != k and g.sim.alive(g.sim.people[x]) and g.sim.people[x].group in ["adult", "elder"])
	return {"id": String(pool[rnd.randi() % pool.size()]), "killer": false}


static func _fill(s: String, vars: Dictionary) -> String:
	var out: String = s
	for k in vars:
		out = out.replace("{%s}" % k, String(vars[k]))
	return out


## Called at dawn for the night that has just passed. May raise a pending event (see `pending`): {id, kind, title, text, choices: [{id, label}]}.
static func dawn(g: RefCounted) -> void:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	var day: int = int(g.sim.day)
	if st.has("pending") or day < 2 or String(g.case.get("status", "")) in ["solved"] or int(st["quiet_until"]) >= day:
		return
	var c: Dictionary = g._truth
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash("%d|dread|%s|%d" % [g.seed_v, c.get("id", ""), day])
	var serial_on: bool = Serial.active(g.serial) and (g.serial["kills"] as Array).size() >= 1
	var alerted: bool = bool(c.get("alerted", false)) and String(c.get("status", "")) == "open"
	# the killer writes (serial: after the second body; one who knows you are close: once)
	var letter_ok: bool = int(st["letters"]) < 4 and day - int(st["last"]) >= 3
	if letter_ok and ((serial_on and (g.serial["kills"] as Array).size() >= 2 and rnd.randf() < 0.3) or (alerted and int(st["letters"]) == 0 and rnd.randf() < 0.4)):
		_raise_letter(g, rnd, serial_on)
		return
	# a night event, more likely in the dark hours you kept, at high stress, and when a killer is hunting
	var late: bool = int(st["late"]) == day - 1 or int(st["late"]) == day
	var p: float = 0.06 + float(det.stress) / 500.0 + (0.08 if late else 0.0) + (0.1 if serial_on else 0.0) + (0.06 if alerted else 0.0)
	if day - int(st["last"]) < QUIET_AFTER or rnd.randf() >= p:
		return
	_raise_event(g, rnd, serial_on or alerted)


static func _trace_of(g: RefCounted, actor: String, rnd: RandomNumberGenerator) -> Dictionary:
	var tr: String = CaseEngine.trace_for(String(g.sim.people[actor].job))
	var tag := "true"
	if rnd.randf() < 0.2:                            # a stray trace of someone else's trade
		var others := ["flour dust", "kitchen grease", "printer ink", "chalk dust", "potting soil", "antiseptic"]
		tr = String(others[rnd.randi() % others.size()])
		tag = "misleading"
	return {"trace": tr, "tag": tag}


static func _raise_event(g: RefCounted, rnd: RandomNumberGenerator, hunted: bool) -> void:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	var d: Dictionary = _d()
	var c: Dictionary = g._truth
	var kinds := ["followed", "note", "silence", "lamp"]
	var kind: String = kinds[rnd.randi() % kinds.size()]
	var killer_ok: bool = hunted and rnd.randf() < 0.65
	var actor: Dictionary = _actor(g, rnd, killer_ok)
	var aid: String = String(actor["id"])
	var home: String = String(g.me().home)
	var tr: Dictionary = _trace_of(g, aid, rnd)
	if bool(st.get("watch", false)):
		tr["tag"] = "true"
	var t: float = 25.0 + rnd.randf() * 3.0
	var ev: Dictionary = d["events"][kind]
	var vars := {"t": Brief.clock_text(fposmod(t, 24.0)), "place": g.place_name(home), "trace": tr["trace"], "fig": _pick(Prose.json("detective/watch.json")["figures"], "%s|%d" % [aid, int(t * 10)]), "msg": _pick(ev.get("msgs", ["LEAVE IT"]), aid)}
	var tmpl: Array = []
	var cert := 0.9 if bool(st.get("watch", false)) else 0.7
	match kind:
		"followed":
			tmpl.append(Claims.make("seen", "", "figure_seen", home, t, String(vars["fig"]), cert, "true" if bool(actor["killer"]) else "misleading"))
		"note":
			tmpl.append(Claims.make("found", "", "note_left", home, t, String(vars["msg"]).to_lower(), 1.0))
		"silence":
			var from_lot: String = String(g.sim.people[aid].home) if rnd.randf() < 0.5 else "post_office"
			if not g.layout.by_id.has(from_lot):
				from_lot = String(g.sim.people[aid].home)
			vars["place"] = g.place_name(from_lot)
			tmpl.append(Claims.make("recorded", "", "call_logged", from_lot, t, "", 0.9, "true"))
		"lamp":
			tmpl.append(Claims.make("found", "", "lamp_out", home, t, "bulb unscrewed", 1.0))
	tmpl.append(Claims.make("found", "", "trace_found", home, t, String(tr["trace"]), cert, String(tr["tag"]) if bool(actor["killer"]) else "misleading"))
	var text: String = Prose.clean(_fill(_pick(ev["scene"], "%s|%s|%d" % [c.get("id", ""), kind, int(g.sim.day)]), vars))
	if bool(st.get("watch", false)):
		text += " " + _fill(String(d["watch_payoff"]), {"n": CaseEngine.name_of(g.sim, aid) if bool(actor["killer"]) else "someone you cannot name", "t": vars["t"]})
		st["watch"] = false
		if bool(actor["killer"]):
			tmpl.append(Claims.make("seen", aid, "followed_detective", home, t, "", 0.85, "true"))
	var eid := "dread_%s_%d" % [kind, int(g.sim.day)]
	var e := {"id": eid, "title": String(ev["title"]).capitalize(), "text": text, "kind": "physical", "source": home, "day": int(g.sim.day)}
	e["claims"] = Claims.emit(c, tmpl, home, text)
	det.learn(e)
	det.add_stress(4.0)
	st["last"] = int(g.sim.day)
	st["events"].append(eid)
	st["pending"] = {"id": eid, "kind": kind, "title": String(ev["title"]), "text": text, "actor_killer": bool(actor["killer"]),
		"choices": [{"id": "report", "label": d["choices"]["report"]["label"]}, {"id": "watch", "label": d["choices"]["watch"]["label"]}, {"id": "ignore", "label": d["choices"]["ignore"]["label"]}]}
	g.today.append("In the night: %s" % String(ev["title"]).capitalize())


static func _raise_letter(g: RefCounted, rnd: RandomNumberGenerator, serial_on: bool) -> void:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	var d: Dictionary = _d()["letters"]
	var c: Dictionary = g._truth
	var k: String = String(c.get("killer", ""))
	var tr: String = CaseEngine.trace_for(String(g.sim.people[k].job)) if g.sim.people.has(k) else "grey cotton lint"
	var home: String = String(g.me().home)
	var item: String = String(g.serial.get("signature", c.get("held_back", ""))) if serial_on else String(c.get("held_back", ""))
	var block: Dictionary = d["serial"] if serial_on else d["plain"]
	var vars := {"sig": item, "held": item, "trace": "a smell of " + tr, "place": g.place_name(String(c.get("scene", home)))}
	var text: String = Prose.clean(_fill(_pick(block["scene"], "%s|letter|%d" % [c.get("id", ""), int(st["letters"])]), vars))
	var tmpl: Array = [Claims.make("found", "", "letter_left", home, 26.0, item.to_lower(), 1.0), Claims.make("found", "", "letter_signature", home, -1.0, item.to_lower(), 1.0)]
	var eid := "letter_%d" % (int(st["letters"]) + 1)
	var e := {"id": eid, "title": String(block["title"]).capitalize(), "text": text, "kind": "physical", "source": home, "day": int(g.sim.day)}
	e["claims"] = Claims.emit(c, tmpl, home, text)
	det.learn(e)
	det.add_stress(6.0)
	st["letters"] = int(st["letters"]) + 1
	st["last"] = int(g.sim.day)
	st["pending"] = {"id": eid, "kind": "letter", "title": String(block["title"]), "text": text, "serial": serial_on, "trace": tr,
		"choices": [{"id": "report", "label": d["choices"]["report"]["label"]}, {"id": "answer", "label": d["choices"]["answer"]["label"]}, {"id": "ignore", "label": d["choices"]["ignore"]["label"]}]}
	g.today.append("A sign was left for you in the night.")


static func pending(det: RefCounted) -> Dictionary:
	return state(det).get("pending", {})


## Respond to the pending event or letter. Returns {text}.
static func respond(g: RefCounted, choice: String) -> Dictionary:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	var pend: Dictionary = st.get("pending", {})
	if pend.is_empty():
		return {"text": ""}
	var d: Dictionary = _d()
	var day: int = int(g.sim.day)
	var c: Dictionary = g._truth
	var home: String = String(g.me().home)
	var text := ""
	if String(pend["kind"]) == "letter":
		var ch: Dictionary = d["letters"]["choices"][choice if choice in ["report", "answer"] else "ignore"]
		text = _fill(_pick(ch["result"], "%s|%s|%d" % [c.get("id", ""), choice, day]), {"trace": "a smell of " + String(pend["trace"])})
		match choice:
			"report":
				Reputation.apply(det, "letter_reported", day)
				det.add_stress(-4.0)
				if Serial.active(g.serial):
					g.serial["pressure"] = maxf(float(g.serial["pressure"]) - 3.0, 0.0)
				var e := {"id": "lab_%s" % pend["id"], "title": "Lab: the letter paper", "text": "The lab finds a trace on the paper: %s." % pend["trace"], "kind": "lab", "source": "lab", "day": day}
				e["claims"] = Claims.emit(c, [Claims.make("found", "", "trace_found", home, -1.0, String(pend["trace"]), 0.8)], "lab", e["text"])
				det.learn(e)
			"answer":
				det.add_stress(2.0)
				if Serial.active(g.serial):
					g.serial["pressure"] = minf(float(g.serial["pressure"]) + 4.0, 100.0)
					g.serial["next_strike"] = maxi(int(g.serial.get("next_strike", day + 2)) - 1, day + 1)
				st["reply_day"] = day + 1
			_:
				det.add_stress(5.0)
	else:
		var ch2: Dictionary = d["choices"][choice if choice in ["report", "watch"] else "ignore"]
		text = String(_pick(ch2["events"], "%s|%s|%d" % [c.get("id", ""), choice, day]))
		match choice:
			"report":
				Reputation.apply(det, "letter_reported", day)
				det.add_stress(-3.0)
				st["quiet_until"] = day + 3
			"watch":
				det.add_stress(3.0)
				st["watch"] = true
			_:
				det.add_stress(4.0)
				st["quiet_until"] = -1
				st["last"] = int(st["last"]) - 1
	st.erase("pending")
	return {"text": Prose.clean(text)}


## The killer answers a reply in the Courier: one more letter, and this time a slip in the paper.
static func reply_due(g: RefCounted) -> void:
	var det: RefCounted = g.det
	var st: Dictionary = state(det)
	if int(st.get("reply_day", -1)) < 0 or int(g.sim.day) < int(st["reply_day"]) or st.has("pending"):
		return
	st["reply_day"] = -1
	var d: Dictionary = _d()["letters"]
	var c: Dictionary = g._truth
	var k: String = String(c.get("killer", ""))
	var tr: String = CaseEngine.trace_for(String(g.sim.people[k].job)) if g.sim.people.has(k) else "grey cotton lint"
	var home: String = String(g.me().home)
	var text: String = Prose.clean(_fill(_pick(d["reply"]["scene"], "%s|reply" % c.get("id", "")), {"trace": "a smell of " + tr}))
	var e := {"id": "letter_reply_%d" % int(g.sim.day), "title": String(d["reply"]["title"]).capitalize(), "text": text, "kind": "physical", "source": home, "day": int(g.sim.day)}
	e["claims"] = Claims.emit(c, [Claims.make("found", "", "letter_left", home, 26.0, "a reply", 1.0), Claims.make("found", "", "trace_found", home, -1.0, tr, 0.9)], home, text)
	det.learn(e)
	det.add_stress(4.0)
	g.today.append("The killer wrote back.")
