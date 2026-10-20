extends RefCounted
## The town sim as a game: one day at a time, in somebody else's body. This is the model; the screens are views of it.
## Wake in a resident -> read the briefing -> live their day however you like -> night (change someone's night) -> dawn: someone new.
## No story is needed for any of it: the town is the content.

const World = preload("res://scripts/sim/sim_world.gd")
const Cause = preload("res://scripts/sim/cause.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Talk = preload("res://scripts/sim/talk.gd")

const COOLDOWN_DAYS := 14

var sim: RefCounted
var cause: RefCounted
var host := ""
var hosts: Array = []             # [{day, id, name, money, mood, left_tick}] everyone you have been
var phase := "day"                # day | night
var night_budget := 2
var chronicle: Array = []         # [{day, text}] the town's news, kept
var today: Array = []             # what happened to you today (lines)
var talks_today := 0
var layout: RefCounted
var _seen_events := 0


func _init(seed_value: int = 1961, first_host: String = "") -> void:
	sim = World.new(seed_value, true)
	sim.decisions_vanish = false
	sim.thin_weeks = false
	cause = Cause.new()
	layout = Brief.layout()
	sim.start_day()
	wake(first_host if first_host != "" else _pick_host())


func _recent() -> Array:
	var out: Array = []
	for h in hosts.slice(-COOLDOWN_DAYS):
		out.append(h["id"])
	return out


func days_since() -> Dictionary:
	var d: Dictionary = {}
	for h in hosts:
		d[h["id"]] = sim.day - int(h["day"])
	return d


func _pick_host() -> String:
	var r: Array = cause.ranking_open(sim, _recent(), days_since())
	return r[0]["id"] if not r.is_empty() else sim.order[0]


func wake(id: String) -> void:
	host = id
	sim.take_control(id)
	var p: RefCounted = sim.people[id]
	p.location = p.home
	phase = "day"
	night_budget = int(cause.cfg["night_actions"])
	talks_today = 0
	today = []
	hosts.append({"day": sim.day, "id": id, "name": p.display, "money": p.money, "mood": p.mood()})


func me() -> RefCounted:
	return sim.people[host]


func brief() -> Dictionary:
	return Brief.make(sim, host)


func place_name(place: String) -> String:
	return Brief.place_name(sim, place, host)


func now_text() -> String:
	return "%s  Day %d, %s" % [Brief.clock_text(sim.hour_now()), sim.day, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][sim.weekday()]]


func people_here() -> Array:
	var out: Array = []
	for q in sim._witnesses(me()):
		out.append(q.id)
	return out


func distance(a: String, b: String) -> float:
	var la: Dictionary = layout.by_id.get(a, {})
	var lb: Dictionary = layout.by_id.get(b, {})
	if la.is_empty() or lb.is_empty():
		return 0.0
	return Vector2(float(la["x"]), float(la["y"])).distance_to(Vector2(float(lb["x"]), float(lb["y"])))


## Walk somewhere. Distance costs time: every 450 m is half an hour.
func go(place: String) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "It's too late to go anywhere."}
	var p := me()
	if place == p.location:
		return {"ok": false, "text": "You're already here."}
	var ticks := int(distance(p.location, place) / 450.0)
	p.location = place
	if ticks > 0:
		sim.player_activity = "errand"
		p.activity = "errand"
		sim.advance(ticks)
	return {"ok": true, "text": "You walk to %s (%d min)." % [place_name(place), ticks * 30], "ticks": ticks}


func do(act: String, hours: float = 1.0) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "The day is over."}
	var r: Dictionary = sim.player_do(act, "", int(hours * 2.0))
	_collect()
	return r


func talk(npc: String, topic: String) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "It's too late."}
	if not people_here().has(npc):
		return {"ok": false, "text": "They're not here."}
	var r: Dictionary = Talk.say(sim, host, npc, topic)
	talks_today += 1
	sim.player_activity = "socialize"
	me().activity = "socialize"
	sim.advance(1)
	_collect()
	return r


## Anything else: steal, gift, insult, spread_rumor, quit_job, sell_house, leave_town, confess, propose...
func act(action: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = sim.player_act(host, action, args)
	_collect()
	return r


func _collect() -> void:
	for i in range(_seen_events, sim.events.size()):
		var e: Dictionary = sim.events[i]
		if e["type"] in ["theft", "quarrel", "vacancy", "decision"]:
			chronicle.append({"day": sim.day, "text": e["text"]})
	_seen_events = sim.events.size()


func hours_left() -> float:
	return (int(sim.tuning["ticks_per_day"]) - sim.clock) * 0.5


## Done for the day: the town runs on to midnight with you resting wherever you are.
func end_day() -> void:
	if phase != "day":
		return
	var p := me()
	sim.player_activity = "sleep" if p.location == p.home else "relax"
	p.activity = sim.player_activity
	sim.advance(int(sim.tuning["ticks_per_day"]) - sim.clock)
	_collect()
	phase = "night"
	hosts[-1]["money_end"] = p.money
	hosts[-1]["mood_end"] = p.mood()


func night_edges() -> Array:
	return cause.edge_report(sim, [])


## Spend a visit changing someone's night (comfort / unsettle). Steers who you become.
func night_visit(action: String, target: String) -> Dictionary:
	if phase != "night" or night_budget <= 0:
		return {"ok": false, "text": "It's nearly dawn."}
	var r: Dictionary = cause.night_action(sim, action, target)
	if r["ok"]:
		night_budget -= 1
	return r


## The Swap. Whoever is most ready to change is who you wake up as.
func dawn() -> String:
	if phase != "night":
		end_day()
	sim.release_control()
	sim.slack()
	sim.start_day()
	_seen_events = 0
	var nid := _pick_host()
	wake(nid)
	return nid


## Everyone you have been, and how they are now. The long arc of the lives you touched.
func lives_report() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for h in hosts:
		if seen.has(h["id"]):
			continue
		seen[h["id"]] = true
		var p: RefCounted = sim.people[h["id"]]
		var gone: bool = not sim.alive(p)
		out.append({"id": h["id"], "name": h["name"], "day": h["day"], "gone": gone,
			"money_then": int(float(h.get("money_end", h["money"]))), "money_now": int(p.money),
			"mood_then": h.get("mood_end", h["mood"]), "mood_now": p.mood(), "mood_word": p.mood_word()})
	return out
