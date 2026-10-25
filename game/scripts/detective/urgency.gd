extends RefCounted
## Urgency. Trails go cold, and the game tells you which and when. Everything here is built from the public case file, the notebook and
## the rules the town runs by (the days a sample keeps, when memories start to go, the pattern a killer has shown), never from what is
## hidden. A warning always comes before the loss, so delay is costly but never unfair. It scales with the serial killer's pressure.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Serial = preload("res://scripts/detective/serial.gd")

const GOES_COLD := 14
const SAMPLE_WEAK := 4
const SAMPLE_SPOIL := 8


static func _d() -> Dictionary:
	return Prose.json("detective/urgency.json")


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


static func _s(n: int) -> String:
	return "" if n == 1 else "s"


static func tier(days_left: int) -> String:
	return "urgent" if days_left <= 0 else ("warn" if days_left <= 1 else "calm")


static func tag(t: String) -> String:
	var d: Dictionary = _d()
	return String(d["urgent_tag"] if t == "urgent" else (d["warn_tag"] if t == "warn" else d["calm_tag"]))


static func days_open(g: RefCounted) -> int:
	return int(g.sim.day) - int(g.case.get("day", 0)) - 1


## Every trail that is going cold: [{id, kind, label, days_left, tier, text}], soonest first.
static func trails(g: RefCounted) -> Array:
	var d: Dictionary = _d()
	var det: RefCounted = g.det
	var out: Array = []
	var n_open: int = days_open(g)
	var cid: String = String(g.case.get("id", ""))
	var st: String = String(g.case.get("status", "open"))
	if st != "open":
		return out
	# samples you hold and have not sent
	var sent := {}
	for l in det.lab:
		sent[String(l.get("clue", ""))] = true
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		if e.get("lab", false) and not sent.has(String(eid)) and not det.lab_done.has(eid) and not String(eid).contains(":"):
			var what: String = String(e.get("title", "the sample")).to_lower()
			var left_weak: int = SAMPLE_WEAK - n_open
			var left_spoil: int = SAMPLE_SPOIL - n_open
			if left_weak >= 0:
				out.append({"id": "lab_" + eid, "kind": "lab_weak", "what": what, "label": "Sample weakens: %s" % what, "days_left": left_weak, "tier": tier(left_weak), "text": _pick(d["lab_weak"], cid + eid).replace("{what}", what).replace("{n}", str(maxi(left_weak, 1))).replace("{s}", _s(maxi(left_weak, 1)))})
			elif left_spoil >= 0:
				out.append({"id": "lab_" + eid, "kind": "lab_spoil", "what": what, "label": "Sample spoils: %s" % what, "days_left": left_spoil, "tier": tier(left_spoil), "text": _pick(d["lab_spoil"], cid + eid).replace("{what}", what).replace("{n}", str(maxi(left_spoil, 1))).replace("{s}", _s(maxi(left_spoil, 1)))})
	# people your notes name whom you have not yet questioned
	var asked := {}
	for s in det.statements:
		asked[String(s["npc"])] = true
	var shown := 0
	for pid in g.persons_of_interest():
		if not asked.has(pid) and shown < 2:
			var left_w: int = 3 - n_open
			if left_w >= -1:
				shown += 1
				out.append({"id": "wit_" + pid, "kind": "witness", "label": "Memory fades: %s" % CaseEngine.first(g.sim, String(pid)), "days_left": left_w, "tier": tier(left_w), "who": pid, "text": _pick(d["witness"], cid + pid).replace("{n}", CaseEngine.first(g.sim, String(pid)))})
	# the scene itself
	for th in [3, 5, 6, 7]:
		if n_open < th:
			var lt: int = th - n_open
			out.append({"id": "tracks", "kind": "tracks", "label": "Scene evidence goes", "days_left": lt, "tier": tier(lt), "text": _pick(d["tracks"], cid)})
			break
	# a serial killer's pattern, once you have seen it twice
	if Serial.active(g.serial) and (g.serial["kills"] as Array).size() >= 2:
		var last: Dictionary = (g.serial["kills"] as Array)[-1]
		var a: int = int(last.get("day", 0)) + 2
		var b: int = int(last.get("day", 0)) + 3
		var lt2: int = a - int(g.sim.day)
		out.append({"id": "strike", "kind": "strike", "label": "Next strike window", "days_left": lt2, "tier": tier(lt2), "text": _pick(d["strike"], cid).replace("{a}", str(a)).replace("{b}", str(b))})
		var dl: int = Serial.days_left(g.serial, int(g.sim.day))
		if dl >= 0:
			out.append({"id": "deadline", "kind": "deadline", "label": "State police deadline", "days_left": dl, "tier": tier(dl), "text": _pick(d["deadline"], cid).replace("{n}", str(maxi(dl, 1))).replace("{s}", _s(maxi(dl, 1)))})
	# the file
	if not Serial.active(g.serial):
		var cl: int = GOES_COLD - n_open
		if cl <= 9:
			out.append({"id": "cold", "kind": "cold", "label": "File goes cold", "days_left": cl, "tier": tier(cl), "text": _pick(d["cold"], cid).replace("{n}", str(maxi(cl, 1))).replace("{s}", _s(maxi(cl, 1)))})
	# a suspect in custody
	if String(g.court.get("custody", "")) != "":
		var td: int = int(g.court.get("trial_day", 0)) - int(g.sim.day)
		out.append({"id": "custody", "kind": "custody", "label": "Trial day", "days_left": td, "tier": tier(td), "text": _pick(d["custody"], cid).replace("{d}", str(int(g.court.get("trial_day", 0))))})
	out.sort_custom(func(x, y): return int(x["days_left"]) < int(y["days_left"]))
	return out


## Lines for the morning card and the Sheriff: a warning for every trail one day from loss, the Sheriff's call and a news line that grow with
## the killer's pressure. Appended to the day's page by the game at dawn.
static func morning(g: RefCounted) -> Array:
	var d: Dictionary = _d()
	var lines: Array = []
	var cid: String = String(g.case.get("id", ""))
	for t in trails(g):
		if int(t["days_left"]) == 1 and String(t["kind"]) != "tracks":
			var tmpl: Array = d["morning"].get(String(t["kind"]), [])
			if not tmpl.is_empty():
				var line: String = _pick(tmpl, cid + String(t["id"])).replace("{what}", String(t.get("what", "it"))).replace("{n}", CaseEngine.first(g.sim, String(t.get("who", g.case.get("found_by", "")))) if String(t["kind"]) == "witness" else "")
				lines.append(line)
	var pr: float = float(g.serial.get("pressure", 0.0)) if Serial.active(g.serial) else 0.0
	if pr >= 30.0:
		var key: String = "low" if pr < 50.0 else ("mid" if pr < 75.0 else "high")
		lines.append(_pick(d["sheriff"][key], cid + "|sheriff|%d" % int(g.sim.day)))
		lines.append(_pick(d["news"][key], cid + "|news|%d" % int(g.sim.day)))
	return lines
