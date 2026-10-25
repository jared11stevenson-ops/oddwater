extends RefCounted
## Hunches. A lead is a suggestion of where to look next, built from the gaps in YOUR notebook and the public case file: a tape not watched,
## an hour nobody has accounted for on a street, a person who has not been asked. It reads no truth, so it can be incomplete, and it is
## sometimes off by an hour or a street. It is never a verdict.

const Prose = preload("res://scripts/detective/prose.gd")
const Sheet = preload("res://scripts/detective/sheet.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")

const WINDOWS := [["the evening, 6 pm to midnight", 18.0, 24.0], ["midnight to 3 am", 24.0, 27.0], ["3 am to 6 am", 27.0, 30.0]]


static func _pick(arr: Array, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(salt)
	return String(arr[r.randi() % arr.size()])


static func street_name(street_id: String) -> String:
	var m: Dictionary = Prose.json("detective/sheet.json")["streets"]
	return String(m.get(street_id, street_id.replace("_", " ").capitalize()))


## Returns {text, kind}. `g` is the DetectiveGame, used through its public face only (cameras, people of interest, notebook, case file).
static func lead(g: RefCounted, n_used: int) -> Dictionary:
	var d: Dictionary = Prose.json("detective/sheet.json")
	var det: RefCounted = g.det
	var cid: String = String(g.case.get("id", "case"))
	var salt := "%s|lead|%d|%d" % [cid, n_used, det.order.size()]
	var cands: Array = []
	# tapes not watched
	for cam in g.cameras():
		for w in WINDOWS:
			if not det.watched.has(g._wkey(String(cam["id"]), float(w[1]), float(w[2]))):
				cands.append({"w": 3, "kind": "tape", "text": _pick(d["lead"]["tape"], salt + String(cam["id"])).replace("{cam}", String(cam["label"])).replace("{band}", String(w[0]))})
	# people named who have not been asked for their night
	var told := {}
	for st in det.statements:
		if String(st["topic"]) == "alibi" and String(st.get("about", "")) in ["", String(st["npc"])]:
			told[st["npc"]] = true
	for pid in g.persons_of_interest():
		if not told.has(pid):
			cands.append({"w": 2, "kind": "alibi", "text": _pick(d["lead"]["alibi"], salt + pid).replace("{n}", CaseEngine.first(g.sim, String(pid)))})
	# hours with nothing in the notebook, on the street of the scene or of someone named
	var win: Array = Reasoning.death_window(det.known)
	var streets: Array = []
	var sc: Dictionary = g.layout.by_id.get(String(g.case.get("scene", "")), {})
	if not sc.is_empty():
		streets.append(street_name(String(sc.get("street", ""))))
	for pid2 in g.persons_of_interest().slice(0, 4):
		var hl: Dictionary = g.layout.by_id.get(String(g.sim.people[pid2].home), {})
		if not hl.is_empty() and not streets.has(street_name(String(hl.get("street", "")))):
			streets.append(street_name(String(hl.get("street", ""))))
	var h0: int = int(floor(float(win[0])))
	for hh in range(h0 - 1, h0 + 4):
		var n := 0
		for e in det.known.values():
			for cl in e.get("claims", []):
				var t: float = float(cl.get("time", -1.0))
				if t >= float(hh) and t < float(hh + 1) and String(cl.get("predicate", "")) != "time_of_death":
					n += 1
		if n == 0 and not streets.is_empty():
			var st_name: String = streets[absi(hash(salt + str(hh))) % streets.size()]
			cands.append({"w": 3, "kind": "hour", "hour": hh, "street": st_name, "tmpl": _pick(d["lead"]["hour"], salt + str(hh)), "text": ""})
	# places named in the notebook that you have never stood at
	var seen_pl := {}
	for e2 in det.known.values():
		for cl2 in e2.get("claims", []):
			var pl: String = String(cl2.get("place", ""))
			if pl != "" and not det.visited.has(pl) and g.layout.by_id.has(pl) and not seen_pl.has(pl) and String(g.layout.by_id[pl]["kind"]) != "house":
				seen_pl[pl] = true
				cands.append({"w": 1, "kind": "place", "text": _pick(d["lead"]["place"], salt + pl).replace("{place}", g.place_name(pl))})
	# the dead: who were they close to
	if not _dossier_has(det, "victim_loved"):
		cands.append({"w": 1, "kind": "friend", "text": _pick(d["lead"]["friend"], salt + "v").replace("{v}", CaseEngine.first(g.sim, String(g.case.get("victim", ""))))})
	if cands.is_empty():
		return {"kind": "none", "text": _pick(d["lead"]["none"], salt)}
	var total := 0
	for c in cands:
		total += int(c["w"])
	var roll: int = absi(hash(salt + "|roll")) % total
	var chosen: Dictionary = cands[0]
	for c in cands:
		roll -= int(c["w"])
		if roll < 0:
			chosen = c
			break
	var text: String = String(chosen["text"])
	# a hunch is a feeling: sometimes the hour is off by one, sometimes it hints at more than it can say
	if chosen["kind"] == "hour":
		var hh2: int = int(chosen["hour"])
		if absi(hash(salt + "|off")) % 100 < 30:
			hh2 += 1 if absi(hash(salt + "|dir")) % 2 == 0 else -1
		var band_txt := "the hour from %s to %s" % [Sheet._clock(float(hh2)), Sheet._clock(float(hh2 + 1))]
		text = String(chosen["tmpl"]).replace("{band}", band_txt).replace("{street}", String(chosen["street"]))
	var tail := ""
	var r: int = absi(hash(salt + "|tail")) % 100
	if r < 35:
		tail = " " + _pick(d["lead_hedge"], salt + "h")
	elif r < 50:
		tail = " " + _pick(d["lead_more"], salt + "m")
	return {"kind": String(chosen["kind"]), "text": Prose.clean(text + tail)}


static func _dossier_has(det: RefCounted, pred: String) -> bool:
	for e in det.known.values():
		for cl in e.get("claims", []):
			if String(cl.get("predicate", "")) == pred:
				return true
	return false
