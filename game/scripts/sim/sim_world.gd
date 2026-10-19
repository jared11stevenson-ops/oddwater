extends RefCounted
## The living town. Every named person has needs, a routine and opinions, and keeps living when the player isn't looking.
## Deterministic for a given seed. The player can take over any person for a day (player_act); the sim runs the rest.

const Data = preload("res://scripts/core/data.gd")
const SimPerson = preload("res://scripts/sim/sim_person.gd")

const HAUNTS := ["low_water", "pink_heron", "rising_loaf", "pageant_green", "library"]

var people: Dictionary = {}
var order: Array = []
var rumors: Array = []
var events: Array = []          # events of the current day
var tuning: Dictionary
var acts: Dictionary
var day := 1
var tick := 0
var seed_base := 1961
var thin_weeks := true
var player_id := ""
var pending: Dictionary = {}    # id -> "struck" | "taken" (resolved at the Slack)
var next_rumor := 1
var wages := {"mayor": 34.0, "dentist": 48.0, "pastor": 22.0, "radio host": 26.0, "nurse": 32.0, "teacher": 24.0}


func _init(seed: int = 1961) -> void:
	seed_base = seed
	tuning = Data.load_json("sim/sim_tuning.json")
	acts = Data.load_json("sim/activities.json")
	for d in Data.load_json("sim/people.json"):
		var p: RefCounted = SimPerson.from_data(d)
		people[p.id] = p
		order.append(p.id)
	for r in Data.load_json("sim/relations.json"):
		if people.has(r["a"]) and people.has(r["b"]):
			people[r["a"]].rel[r["b"]] = {"affinity": float(r["affinity"]), "trust": float(r["trust"])}
			people[r["b"]].rel[r["a"]] = {"affinity": float(r["affinity"]), "trust": float(r["trust"])}


func hour_of(t: int) -> float:
	return float(tuning["day_start_hour"]) + t * float(tuning["tick_hours"])


func _rng(t: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%d|%s" % [seed_base, day, t, salt])
	return r


func log_event(type: String, who: String, text: String, other: String = "") -> void:
	events.append({"day": day, "tick": tick, "type": type, "who": who, "other": other, "text": text})


func alive(p: RefCounted) -> bool:
	return not p.struck and not p.taken


# ------------------------------------------------------------------ autonomy
func choose_activity(p: RefCounted, t: int) -> String:
	var h := hour_of(t)
	if h < p.wake or h >= 23.0:
		return "sleep"
	var n: Dictionary = p.needs
	if float(n["energy"]) < 12.0:
		return "sleep"
	var rng := _rng(t, p.id)
	var scores := {
		"eat": (100.0 - float(n["hunger"])) * 1.1,
		"socialize": (100.0 - float(n["social"])) * 0.9 + p.trait_of("sociable") * 25.0,
		"relax": (100.0 - float(n["fun"])) * 0.7 + (100.0 - float(n["comfort"])) * 0.3,
		"worship": (p.trait_of("pious") * 30.0 if h >= 17.0 and h < 19.0 else 0.0),
		"errand": 8.0}
	if p.employed and h >= p.work_start and h < p.work_end:
		scores["work"] = 70.0 + (10.0 if float(n["purpose"]) < 40.0 else 0.0)
		scores["eat"] = (100.0 - float(n["hunger"])) * 1.5 if float(n["hunger"]) < 25.0 else scores["eat"] * 0.6
	if h >= 21.5:
		scores["relax"] += 30.0
	var best := "relax"
	var best_s := -1.0
	for k in scores:
		var s: float = scores[k] + rng.randf() * 4.0
		if s > best_s:
			best_s = s
			best = k
	return best


func place_for(p: RefCounted, act: String, t: int) -> String:
	var rng := _rng(t, p.id + "place")
	match act:
		"sleep": return p.home
		"work": return p.work if p.work != "" else p.home
		"worship": return "chapel"
		"errand": return ["hardware", "post_office", "rising_loaf"][rng.randi() % 3]
		"eat":
			var h := hour_of(t)
			if (h < 8.5 or h >= 18.5) and p.money > 40.0:
				return p.home
			return ["pink_heron", "rising_loaf", p.home][rng.randi() % 3] if p.money > 15.0 else p.home
		"socialize": return HAUNTS[(rng.randi() + int(p.trait_of("sociable") * 10)) % HAUNTS.size()]
		"relax": return p.home if rng.randf() < 0.6 else "pageant_green"
	return p.home


func _apply_needs(p: RefCounted, act: String) -> void:
	var eff: Dictionary = acts.get(act, {})
	for k in eff:
		if k == "restless":
			continue
		p.needs[k] = clampf(float(p.needs[k]) + float(eff[k]), 0.0, 100.0)
	if act != "sleep":   # waking life wears you down
		p.needs["energy"] = clampf(float(p.needs["energy"]) - 2.2, 0.0, 100.0)
		p.needs["hunger"] = clampf(float(p.needs["hunger"]) - 3.0, 0.0, 100.0)
		p.needs["social"] = clampf(float(p.needs["social"]) - 1.8, 0.0, 100.0)
		p.needs["fun"] = clampf(float(p.needs["fun"]) - 1.8, 0.0, 100.0)
	p.needs["purpose"] = clampf(float(p.needs["purpose"]) - 0.3, 0.0, 100.0)
	# restlessness: stuck routines and the Thin Weeks push a person toward a Decision
	var stuck: float = 0.04 * float(p.routine_streak)
	var up: float = float(tuning["base_restless"]) + (float(tuning["thin_weeks_restless_bonus"]) if thin_weeks else 0.0) + stuck
	var relief: float = -float(eff.get("restless", 0.0))
	p.needs["restless"] = clampf(float(p.needs["restless"]) + up - relief, 0.0, 100.0)
	if p.last_activity == act:
		p.routine_streak = mini(p.routine_streak + 1, 60)
	else:
		p.routine_streak = maxi(p.routine_streak - 3, 0)
	p.last_activity = act
	p.contentment += (float(p.mood()) - 50.0) * 0.01


func step_tick(t: int) -> void:
	tick = t
	for id in order:
		var p: RefCounted = people[id]
		if not alive(p):
			continue
		if id != player_id:
			p.activity = choose_activity(p, t)
			p.location = place_for(p, p.activity, t)
		_apply_needs(p, p.activity if id != player_id else "relax")
		if float(p.needs["restless"]) >= 92.0 and not pending.has(id) and _rng(t, id + "edge").randf() < 0.1:
			log_event("on_the_edge", id, "%s stares at the lake and hasn't moved for an hour." % p.display)
	_interactions(t)


func _interactions(t: int) -> void:
	var by_loc: Dictionary = {}
	for id in order:
		var p: RefCounted = people[id]
		if alive(p):
			by_loc.get_or_add(p.location, []).append(id)
	for loc in by_loc:
		var ids: Array = by_loc[loc]
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: RefCounted = people[ids[i]]
				var b: RefCounted = people[ids[j]]
				var r := _rng(t, a.id + b.id)
				var chatty: bool = a.activity == "socialize" or b.activity == "socialize"
				if r.randf() > (0.55 if chatty else 0.12):
					continue
				var q: float = (a.mood() + b.mood()) / 200.0 + (a.affinity(b.id) + b.affinity(a.id)) / 400.0 + r.randf_range(-0.3, 0.3)
				if q > 0.5:
					a.bump(b.id, 2.0, 1.0)
					b.bump(a.id, 2.0, 1.0)
					a.needs["social"] = clampf(float(a.needs["social"]) + 6.0, 0, 100)
					b.needs["social"] = clampf(float(b.needs["social"]) + 6.0, 0, 100)
				elif q < 0.22 and a.mood() < 45.0 and b.mood() < 45.0:
					a.bump(b.id, -5.0, -2.0)
					b.bump(a.id, -5.0, -2.0)
					log_event("quarrel", a.id, "%s and %s had words at %s." % [a.display, b.display, loc], b.id)
				_share_rumors(a, b, r)


func _share_rumors(a: RefCounted, b: RefCounted, r: RandomNumberGenerator) -> void:
	for ru in rumors:
		for pair in [[a, b], [b, a]]:
			var s: RefCounted = pair[0]
			var l: RefCounted = pair[1]
			var bs: float = float(ru["belief"].get(s.id, 0.0))
			var bl: float = float(ru["belief"].get(l.id, 0.0))
			if bs >= 35.0 and bs > bl and r.randf() < s.trait_of("sociable") * 0.6:
				var gain: float = bs * 0.8 * (0.62 + float(l.trust(s.id)) / 250.0)
				ru["belief"][l.id] = clampf(maxf(bl, gain), 0.0, 100.0)
				if r.randf() < float(tuning["rumor_distort"]):
					ru["severity"] = mini(int(ru["severity"]) + 1, 5)
					ru["distorted"] = true


# ------------------------------------------------------------------ rumours / propaganda
func seed_rumor(subject: String, claim: String, truth: bool, origin: String, severity: int = 2, strength: float = 90.0) -> Dictionary:
	var ru := {"id": next_rumor, "subject": subject, "claim": claim, "truth": truth, "origin": origin, "severity": severity,
		"belief": {origin: strength}, "distorted": false, "day": day}
	next_rumor += 1
	rumors.append(ru)
	log_event("rumor", origin, "A rumour about %s began: \"%s\"" % [subject, claim], subject)
	return ru


## Mass media: the radio or the Gazette lifts belief for everyone who is listening.
func broadcast(rumor_id: int, reach: float = -1.0) -> void:
	var strength: float = (float(tuning["mass_media_strength"]) if reach < 0.0 else reach) * 100.0
	for ru in rumors:
		if ru["id"] == rumor_id:
			for id in order:
				if alive(people[id]):
					ru["belief"][id] = maxf(float(ru["belief"].get(id, 0.0)), strength)


func believers(rumor_id: int, threshold: float = 50.0) -> int:
	for ru in rumors:
		if ru["id"] == rumor_id:
			var n := 0
			for id in ru["belief"]:
				if float(ru["belief"][id]) >= threshold:
					n += 1
			return n
	return 0


func _rumor_fallout() -> void:
	for ru in rumors:
		var subj: String = ru["subject"]
		if not people.has(subj):
			continue
		for id in ru["belief"]:
			var b: float = float(ru["belief"][id])
			if b >= 60.0 and id != subj and people.has(id):
				people[id].bump(subj, -float(ru["severity"]) * 0.06 * b / 100.0 * 10.0, -float(ru["severity"]) * 0.03 * b / 100.0 * 10.0)


# ------------------------------------------------------------------ the player takes over a person
func take_control(id: String) -> void:
	player_id = id


func release_control(notes_in: Dictionary = {}) -> void:
	var p: RefCounted = people.get(player_id)
	if p != null:
		for k in notes_in:
			p.notes[k] = int(notes_in[k])
		# the Chorus's day hardens into the walk-on: warmth -> sociable, candor -> honest, nerve -> bold
		p.traits["sociable"] = clampf(p.trait_of("sociable") + float(notes_in.get("warmth", 0)) / 400.0, 0.0, 1.0)
		p.traits["honest"] = clampf(p.trait_of("honest") + float(notes_in.get("candor", 0)) / 400.0, 0.0, 1.0)
		p.traits["bold"] = clampf(p.trait_of("bold") + float(notes_in.get("nerve", 0)) / 400.0, 0.0, 1.0)
		p.walkon = true
	player_id = ""


func _witnesses(p: RefCounted, except: Array = []) -> Array:
	var out: Array = []
	for id in order:
		var q: RefCounted = people[id]
		if q != p and alive(q) and q.location == p.location and not except.has(id):
			out.append(q)
	return out


## Everything the player can do in a body. Returns {ok, decision, text}. Decisions make the Remnant liable to be Struck.
func player_act(id: String, action: String, args: Dictionary = {}) -> Dictionary:
	var p: RefCounted = people.get(id)
	if p == null or not alive(p):
		return {"ok": false, "decision": false, "text": "nobody there"}
	var tgt: RefCounted = people.get(args.get("target", ""))
	var res := {"ok": true, "decision": false, "text": ""}
	match action:
		"work":
			var hrs: float = float(args.get("hours", 4))
			if not p.employed:
				return {"ok": false, "decision": false, "text": "no job to do"}
			p.money += hrs * float(wages.get(p.job, 20.0))
			p.needs["purpose"] = clampf(float(p.needs["purpose"]) + 4.0 * hrs, 0, 100)
			p.needs["energy"] = clampf(float(p.needs["energy"]) - 4.0 * hrs, 0, 100)
			p.needs["hunger"] = clampf(float(p.needs["hunger"]) - 4.0 * hrs, 0, 100)
			res["text"] = "Worked %d hours." % int(hrs)
		"eat":
			if p.money < 8.0:
				return {"ok": false, "decision": false, "text": "can't afford it"}
			p.money -= 8.0
			p.needs["hunger"] = clampf(float(p.needs["hunger"]) + 45.0, 0, 100)
			res["text"] = "A proper meal."
		"relax":
			p.needs["fun"] = clampf(float(p.needs["fun"]) + 25.0, 0, 100)
			p.needs["comfort"] = clampf(float(p.needs["comfort"]) + 10.0, 0, 100)
			res["text"] = "An hour doing nothing, pleasantly."
		"sleep":
			p.needs["energy"] = clampf(float(p.needs["energy"]) + 40.0, 0, 100)
			res["text"] = "A nap."
		"socialize":
			if tgt == null:
				return {"ok": false, "decision": false, "text": "no one to talk to"}
			p.needs["social"] = clampf(float(p.needs["social"]) + 20.0, 0, 100)
			p.bump(tgt.id, 3.0, 1.0)
			tgt.bump(p.id, 3.0, 1.0)
			res["text"] = "A good chat with %s." % tgt.display
		"gift":
			var amt: float = minf(float(args.get("amount", 20)), p.money)
			if tgt == null or amt <= 0.0:
				return {"ok": false, "decision": false, "text": "nothing to give"}
			p.money -= amt
			tgt.money += amt
			tgt.bump(p.id, amt * 0.3, 2.0)
			tgt.remember(day, p.id, "gave me a gift", 0.6)
			res["text"] = "%s was moved." % tgt.display
		"steal":
			var amt2: float = minf(float(args.get("amount", 50)), tgt.money if tgt != null else 0.0)
			if tgt == null or amt2 <= 0.0:
				return {"ok": false, "decision": false, "text": "nothing to steal"}
			tgt.money -= amt2
			p.money += amt2
			tgt.bump(p.id, -30.0, -40.0)
			tgt.remember(day, p.id, "stole from me", 1.0)
			var seen := _witnesses(p, [tgt.id])
			for w in seen:
				w.remember(day, p.id, "saw %s steal" % p.display, 0.8)
				w.bump(p.id, -10.0, -15.0)
			seed_rumor(p.id, "%s took money that wasn't theirs." % p.display, true, tgt.id, 3, 85.0)
			log_event("theft", p.id, "%s was robbed of %d." % [tgt.display, int(amt2)], tgt.id)
			res["text"] = "You took %d from %s. %d people saw." % [int(amt2), tgt.display, seen.size()]
		"praise":
			if tgt == null:
				return {"ok": false, "decision": false, "text": "no one to praise"}
			tgt.bump(p.id, 6.0, 2.0)
			res["text"] = "%s glowed." % tgt.display
		"insult":
			if tgt == null:
				return {"ok": false, "decision": false, "text": "no one to insult"}
			tgt.bump(p.id, -12.0, -6.0)
			tgt.needs["comfort"] = clampf(float(tgt.needs["comfort"]) - 12.0, 0, 100)
			tgt.remember(day, p.id, "insulted me", 0.8)
			for w in _witnesses(p, [tgt.id]):
				w.remember(day, p.id, "saw an ugly scene", 0.4)
			res["text"] = "That landed."
		"spread_rumor":
			var ru := seed_rumor(args.get("subject", ""), args.get("claim", ""), bool(args.get("truth", false)), p.id, int(args.get("severity", 2)))
			res["text"] = "You let it drop. It's out there now (#%d)." % ru["id"]
		"burn_diary":
			p.needs["restless"] = clampf(float(p.needs["restless"]) - 15.0, 0, 100)
			res["text"] = "The diary burns. Nobody will ever read it. Neither will you."
		"quit_job", "sell_house", "leave_town", "confess", "propose":
			res = _decision(p, action, tgt)
		_:
			return {"ok": false, "decision": false, "text": "unknown action"}
	return res


func _decision(p: RefCounted, what: String, tgt: RefCounted) -> Dictionary:
	var text := ""
	match what:
		"quit_job":
			p.employed = false
			text = "%s quit." % p.display
		"sell_house":
			p.money += 18000.0
			text = "%s sold the house." % p.display
		"leave_town":
			text = "%s bought a ticket." % p.display
		"confess":
			text = "%s confessed." % p.display
			p.needs["restless"] = 0.0
		"propose":
			text = "%s proposed to %s." % [p.display, tgt.display if tgt != null else "someone"]
	# a Remnant is a walk-on; a walk-on who Decides is Struck at the next Slack
	pending[p.id] = "struck" if p.walkon or player_id == p.id else "taken"
	log_event("decision", p.id, text)
	return {"ok": true, "decision": true, "text": text + " It cannot be unsaid."}


# ------------------------------------------------------------------ day cycle
func simulate_rest_of_day(from_tick: int = 0) -> void:
	for t in range(from_tick, int(tuning["ticks_per_day"])):
		step_tick(t)
	_rumor_fallout()


## 4:12. Pending Decisions resolve; the Hush papers over the gaps.
func slack() -> Array:
	var gone: Array = []
	for id in pending.keys():
		var p: RefCounted = people[id]
		if pending[id] == "struck":
			p.struck = true
		else:
			p.taken = true
		p.location = ""
		gone.append(id)
		log_event("vacancy", id, "%s is gone." % p.display)
	pending.clear()
	day += 1
	return gone


func start_day() -> void:
	events = []
	for id in order:
		var p: RefCounted = people[id]
		if alive(p):
			p.location = p.home
			p.activity = "sleep"
			# overnight: rest, hunger, a little social decay
			p.needs["energy"] = clampf(float(p.needs["energy"]) + 45.0, 0, 100)
			p.needs["hunger"] = clampf(float(p.needs["hunger"]) - 12.0, 0, 100)


## What the town's paper prints. A propaganda organ: soft on quarrels and theft, silent on Decisions.
func gazette() -> Array:
	var out: Array = []
	for e in events:
		match e["type"]:
			"quarrel": out.append("Neighbors enjoyed a lively exchange of views.")
			"theft": out.append("A small misunderstanding over a wallet has been happily resolved.")
			"vacancy": out.append("%s has relocated, to be with family. The town wishes them well." % people[e["who"]].display)
			"rumor": out.append("Pleasant talk was heard around town.")
			"on_the_edge": pass
			"decision": pass
	if out.is_empty():
		out.append("Nothing to report.")
	return out


## What actually happened, for the player who can read the ledger.
func ledger() -> Array:
	var out: Array = []
	for e in events:
		out.append("[d%d t%d] %s" % [e["day"], e["tick"], e["text"]])
	return out


func decision_pressure(id: String) -> float:
	var p: RefCounted = people.get(id)
	return float(p.needs["restless"]) if p != null else 0.0


func to_dict() -> Dictionary:
	var ps := {}
	for id in order:
		ps[id] = people[id].to_dict()
	return {"day": day, "people": ps, "rumors": rumors.duplicate(true), "pending": pending.duplicate(), "next": next_rumor, "seed": seed_base}


func load_dict(d: Dictionary) -> void:
	day = int(d["day"]); rumors = d["rumors"].duplicate(true); pending = d["pending"].duplicate(); next_rumor = int(d["next"]); seed_base = int(d["seed"])
	for id in d["people"]:
		if people.has(id):
			people[id].load_dict(d["people"][id])
