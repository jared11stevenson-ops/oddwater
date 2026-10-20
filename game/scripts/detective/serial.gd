extends RefCounted
## Serial killers: rare, careful, and patient. Once one is loose they strike every two or three nights until caught. After the third
## death the town finds out: the paper, the radio, and a pressure meter that eats your reputation, with a deadline after which the state
## police take the case from you. All state lives in one dictionary (`serial`) on the game, so it saves with everything else.

const Prose = preload("res://scripts/detective/prose.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Reputation = preload("res://scripts/detective/reputation.gd")
const News = preload("res://scripts/detective/news.gd")
const Data = preload("res://scripts/core/data.gd")

const CHANCE := 0.02      # about one case in fifty
const DEADLINE_DAYS := 8


static func rolls(seed_v: int, salt: String) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|serial|%s" % [seed_v, salt])
	return r.randf() < CHANCE


static func none() -> Dictionary:
	return {"status": "none", "kills": [], "news": [], "pressure": 0.0, "third_day": -1, "deadline": -1}


static func active(s: Dictionary) -> bool:
	return String(s.get("status", "none")) == "hunting"


## Pick the killer and what they leave behind. Returns the opts CaseEngine.generate wants, merged into a fresh serial dict.
## `used`: signatures earlier killers have already claimed. Every serial killer gets one of their own.
static func begin(sim: RefCounted, seed_v: int, salt: String, used: Array = []) -> Dictionary:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|serial_who|%s" % [seed_v, salt])
	var adults: Array = CaseEngine._adults(sim)
	var killer: String = adults[r.randi() % adults.size()]
	var pool: Array = (cb["signatures"] as Array).filter(func(x): return not used.has(x["text"]))
	if pool.is_empty():
		pool = cb["signatures"]
	var pick: Dictionary = pool[r.randi() % pool.size()]
	var sig: String = pick["text"]
	var nick: String = pick["nick"]
	var s := none()
	s["status"] = "hunting"
	s["killer"] = killer
	s["signature"] = sig
	s["trait"] = String(cb["traits"][r.randi() % cb["traits"].size()])
	s["thread"] = r.randi() % cb["threads"].size()
	s["nick"] = nick
	s["avoid"] = []
	s["next_strike"] = 0
	return s


static func opts(s: Dictionary) -> Dictionary:
	return {"killer": s["killer"], "signature": s["signature"], "trait": s["trait"], "thread": s["thread"], "avoid": s["avoid"], "n": (s["kills"] as Array).size()}


## A murder has been generated and executed for `c`; record it. `day` is the day the body is found.
static func record(sim: RefCounted, s: Dictionary, c: Dictionary, seed_v: int, place: String) -> void:
	s["kills"].append({"day": int(c["day"]) + 1, "victim": c["victim"], "name": CaseEngine.name_of(sim, c["victim"]), "case": c["id"], "place": place})
	s["avoid"].append(c["victim"])
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|gap|%d" % [seed_v, s["kills"].size()])
	s["next_strike"] = int(c["day"]) + 1 + 2 + (r.randi() % 2)      # two or three nights on
	if s["kills"].size() >= 3 and int(s["third_day"]) < 0:
		s["third_day"] = int(c["day"]) + 1
		s["deadline"] = int(s["third_day"]) + DEADLINE_DAYS
		s["pressure"] = 20.0


static func pressure_at(s: Dictionary, day: int) -> float:
	var n: int = (s["kills"] as Array).size()
	if n < 3 or int(s["third_day"]) < 0:
		return 0.0
	return clampf(20.0 + 6.0 * (n - 3) + 10.0 * (day - int(s["third_day"])), 0.0, 100.0)


static func days_left(s: Dictionary, day: int) -> int:
	return maxi(int(s.get("deadline", day)) - day, 0) if int(s.get("deadline", -1)) >= 0 else -1


## Once a morning, after the night's events. Updates pressure, drains reputation, and returns what to tell the player (a front page or {}).
## `fresh` is true when this morning follows a new murder.
static func morning(s: Dictionary, det: RefCounted, day: int, fresh: bool) -> Dictionary:
	if not active(s):
		return {}
	var n: int = (s["kills"] as Array).size()
	if n < 3:
		return {}
	var prev: float = float(s["pressure"])
	s["pressure"] = pressure_at(s, day)
	if fresh and int(s.get("fresh_bonus_day", -1)) != day and n > 3:
		s["pressure"] = minf(float(s["pressure"]) + 10.0, 100.0)
		s["fresh_bonus_day"] = day
	if int(s.get("drain_day", -1)) != day:
		s["drain_day"] = day
		var p: float = float(s["pressure"])
		if p >= 40.0:
			Reputation.apply(det, "serial_pressure" if p >= 70.0 else "serial_pressure_light", day)
		if p >= 70.0:
			Reputation.apply(det, "serial_pressure_siege" if p >= 90.0 else "serial_pressure_sheriff", day)
	var last: Dictionary = (s["kills"] as Array)[-1]
	var page: Dictionary
	if day >= int(s["deadline"]):
		s["status"] = "failed"
		Reputation.apply(det, "serial_failed", day)
		det.cases_failed += 1
		page = News.front_page(s, day, "failed")
	elif fresh:
		page = News.front_page(s, day, "murder", String(last["name"]), String(last["place"]))
	else:
		page = News.front_page(s, day, "day")
	(s["news"] as Array).append(page)
	return page


## The killer is behind bars and the case is closed.
static func caught(s: Dictionary, det: RefCounted, day: int) -> Dictionary:
	if not active(s):
		return {}
	s["status"] = "caught"
	var big := int(s["pressure"]) >= 40
	Reputation.apply(det, "serial_caught_big" if ((s["kills"] as Array).size() >= 3 and big) else "serial_caught", day)
	det.gain_xp(300 if (s["kills"] as Array).size() >= 3 else 120)
	s["pressure"] = 0.0
	var page: Dictionary = News.front_page(s, day, "caught")
	(s["news"] as Array).append(page)
	return page


## A killer who got away once comes back: the same hunt resumes with a last, shorter deadline.
static func resume(s: Dictionary, day: int) -> void:
	s["status"] = "hunting"
	s["resumed"] = int(s.get("resumed", 0)) + 1
	s["third_day"] = day
	s["deadline"] = day + DEADLINE_DAYS + 2
	s["pressure"] = 45.0
	s["next_strike"] = day


## A killer who beat the detective and was never caught starts to leave signs. A fresh hunt with the same hand.
static func adopt(sim: RefCounted, seed_v: int, killer: String, day: int, used: Array) -> Dictionary:
	var s: Dictionary = begin(sim, seed_v, "adopt%d" % day, used)
	s["killer"] = killer
	s["next_strike"] = day
	return s
