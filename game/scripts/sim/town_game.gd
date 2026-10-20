extends RefCounted
## The town sim as a game: one day at a time, in somebody else's body. This is the model; the screens are views of it.
## Wake in a resident -> read the briefing -> live their day however you like -> night (change someone's night) -> dawn: someone new.
## No story is needed for any of it: the town is the content.

const World = preload("res://scripts/sim/sim_world.gd")
const Cause = preload("res://scripts/sim/cause.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Talk = preload("res://scripts/sim/talk.gd")
const Wishes = preload("res://scripts/sim/wishes.gd")

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
var wishes: Array = []            # today's wishes for whoever you are
var stats: Dictionary = {}        # what you have done today (feeds the wishes and the day report)
var wish_points := 0              # lifetime, across every life
var report: Dictionary = {}       # the last end-of-day report
var talk_costs_time := true       # the 2D town: a chat takes half an hour. In 3D the world pauses while you talk
var near: Array = []              # 3D mode: people standing next to you right now count as "here"


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
	var aff: Dictionary = {}
	for oid in p.rel:
		aff[oid] = p.affinity(oid)
	stats = {"ate": 0, "work_ticks": 0, "talked": {}, "kind_to": {}, "gifts": {}, "ticks_at": {}, "outdoor_ticks": 0,
		"money_start": p.money, "mood_start": p.mood(), "aff_start": aff}
	wishes = Wishes.generate(sim, id)


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
	for n in near:
		if not out.has(n) and n != host:
			out.append(n)
	return out


## 3D mode: half an hour of town time passes while you walk about. `lot` is the building you are at or next to ("" keeps the last).
func realtime_tick(lot: String, moving: bool) -> void:
	if phase != "day" or sim.day_over():
		return
	var p := me()
	if lot != "":
		p.location = lot
	var c0: int = sim.clock
	sim.player_activity = "errand" if moving else "relax"
	p.activity = sim.player_activity
	sim.advance(1)
	_collect()
	_account(c0)


func distance(a: String, b: String) -> float:
	var la: Dictionary = layout.by_id.get(a, {})
	var lb: Dictionary = layout.by_id.get(b, {})
	if la.is_empty() or lb.is_empty():
		return 0.0
	return Vector2(float(la["x"]), float(la["y"])).distance_to(Vector2(float(lb["x"]), float(lb["y"])))


## Walk somewhere. Distance costs time: every 450 m is half an hour.
## After anything that passes time: credit the elapsed half-hours to where you are and what you did, then see if a wish came true.
func _account(clock_before: int, act: String = "") -> void:
	var dt: int = sim.clock - clock_before
	var p := me()
	if dt > 0:
		stats["ticks_at"][p.location] = int(stats["ticks_at"].get(p.location, 0)) + dt
		if sim.OUTDOORS.has(p.location):
			stats["outdoor_ticks"] = int(stats["outdoor_ticks"]) + dt
		if act == "work":
			stats["work_ticks"] = int(stats["work_ticks"]) + dt
		if act == "eat":
			stats["ate"] = int(stats["ate"]) + 1
	for w in wishes:
		if not w["done"] and Wishes.check(sim, host, w, stats):
			w["done"] = true
			wish_points += int(w["points"])
			p.needs["purpose"] = clampf(float(p.needs["purpose"]) + 8.0, 0.0, 100.0)
			p.needs["fun"] = clampf(float(p.needs["fun"]) + 5.0, 0.0, 100.0)
			p.needs["restless"] = clampf(float(p.needs["restless"]) - 6.0, 0.0, 100.0)
			today.append("Wish came true: %s" % w["text"])


func go(place: String) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "It's too late to go anywhere."}
	var p := me()
	if place == p.location:
		return {"ok": false, "text": "You're already here."}
	var ticks := int(distance(p.location, place) / 450.0)
	var c0: int = sim.clock
	p.location = place
	if ticks > 0:
		sim.player_activity = "errand"
		p.activity = "errand"
		sim.advance(ticks)
	_account(c0)
	return {"ok": true, "text": "You walk to %s (%d min)." % [place_name(place), ticks * 30], "ticks": ticks}


func do(act: String, hours: float = 1.0) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "The day is over."}
	var c0: int = sim.clock
	var r: Dictionary = sim.player_do(act, "", int(hours * 2.0))
	_collect()
	if r.get("ok", false):
		_account(c0, act)
	return r


func talk(npc: String, topic: String) -> Dictionary:
	if phase != "day" or sim.day_over():
		return {"ok": false, "text": "It's too late."}
	if not people_here().has(npc):
		return {"ok": false, "text": "They're not here."}
	var c0: int = sim.clock
	var r: Dictionary = Talk.say(sim, host, npc, topic)
	talks_today += 1
	stats["talked"][npc] = int(stats["talked"].get(npc, 0)) + 1
	if topic in ["compliment", "joke", "chat", "ask_day", "confide"] and r.get("tone", "") != "cold":
		stats["kind_to"][npc] = true
	sim.player_activity = "socialize"
	me().activity = "socialize"
	if talk_costs_time:
		sim.advance(1)
	_collect()
	_account(c0)
	return r


## Anything else: steal, gift, insult, spread_rumor, quit_job, sell_house, leave_town, confess, propose...
func act(action: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = sim.player_act(host, action, args)
	_collect()
	var tgt: String = args.get("target", "")
	if tgt != "" and r.get("ok", false):
		if action in ["gift", "praise"]:
			stats["kind_to"][tgt] = true
		if action == "gift":
			stats["gifts"][tgt] = true
	_account(sim.clock)
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
	_account(sim.clock)
	report = _make_report()
	hosts[-1]["wishes_done"] = int(report["done"])


func _make_report() -> Dictionary:
	var p := me()
	var done := 0
	for w in wishes:
		if w["done"]:
			done += 1
	# who you grew closer to, who you drove away
	var moves: Array = []
	for oid in p.rel:
		var d: float = float(sim.people[oid].affinity(host)) - float(stats["aff_start"].get(oid, 0.0)) if sim.people.has(oid) else 0.0
		if absf(d) >= 3.0 and sim.people.has(oid):
			moves.append({"id": oid, "name": sim.people[oid].display, "delta": d})
	moves.sort_custom(func(a, b): return absf(a["delta"]) > absf(b["delta"]))
	return {"host": host, "name": p.display, "day": sim.day, "weather": sim.weather_today(), "wishes": wishes.duplicate(true), "done": done,
		"money_delta": int(p.money - float(stats["money_start"])), "mood_delta": p.mood() - float(stats["mood_start"]), "mood_word": p.mood_word(),
		"talks": talks_today, "moves": moves.slice(0, 3), "news": today.duplicate(), "points": wish_points}


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
			"mood_then": h.get("mood_end", h["mood"]), "mood_now": p.mood(), "mood_word": p.mood_word(), "wishes_done": int(h.get("wishes_done", 0))})
	return out


# ------------------------------------------------------------------ saving: the whole town, and who you have been
const SAVE_PATH := "user://town_save.json"
const SAVE_VERSION := 2


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "seed": sim.seed_base, "sim": sim.to_dict(), "host": host, "hosts": hosts.duplicate(true), "phase": phase,
		"night_budget": night_budget, "chronicle": chronicle.duplicate(true), "talks_today": talks_today, "today": today.duplicate(), "seen": _seen_events,
		"wishes": wishes.duplicate(true), "stats": stats.duplicate(true), "wish_points": wish_points, "report": report.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	sim.load_dict(d["sim"])
	host = d["host"]
	hosts = d["hosts"].duplicate(true)
	phase = d["phase"]
	night_budget = int(d["night_budget"])
	chronicle = d["chronicle"].duplicate(true)
	talks_today = int(d["talks_today"])
	today = d["today"].duplicate()
	_seen_events = int(d["seen"])
	wishes = d.get("wishes", []).duplicate(true)
	stats = d.get("stats", stats).duplicate(true)
	wish_points = int(d.get("wish_points", 0))
	report = d.get("report", {}).duplicate(true)
	for h in hosts:
		h["day"] = int(h["day"])
	for c in chronicle:
		c["day"] = int(c["day"])


## Write atomically (temp file, then rename) so a crash mid-save never costs the town.
func save(path: String = SAVE_PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "", true, true))      # full float precision: the town must resume exactly
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Returns the loaded game, or null if there is no usable save.
static func load_game(path: String = SAVE_PATH) -> RefCounted:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != SAVE_VERSION:
		return null
	var g: RefCounted = load("res://scripts/sim/town_game.gd").new(int(d["seed"]), d["host"])
	g.load_dict(d)
	return g


static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
