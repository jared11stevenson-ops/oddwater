extends RefCounted
## The case sheet (Obra Dinn style). The detective fills in WHO, WHEN, WHERE, HOW and WHY and cites, for each answer, the notebook claims
## that support it. The game never says which answer is right. It stamps a LINKED GROUP as confirmed only when the group is jointly correct
## and the cited claims really establish it (by the rules of evidence, with the private truth tags applied at adjudication); otherwise the
## stamp reads "not yet supported", whatever the reason. The three groups: THE NIGHT (who, where, when), THE ACT (who, how), THE REASON
## (who, why). What a confirmed group allows is the CHARGE LADDER: all three is murder, the night plus one other is unlawful killing, any
## one is a hold on suspicion. Adjudication is the one place here that meets the truth; everything else reads the notebook only.

const Reasoning = preload("res://scripts/detective/reasoning.gd")
const Claims = preload("res://scripts/detective/claims.gd")
const Prose = preload("res://scripts/detective/prose.gd")

const BANDS := [
	{"id": "eve", "label": "6 to 9 pm", "from": 18.0, "to": 21.0},
	{"id": "night", "label": "9 pm to midnight", "from": 21.0, "to": 24.0},
	{"id": "small", "label": "Midnight to 3 am", "from": 24.0, "to": 27.0},
	{"id": "dawn", "label": "3 to 6 am", "from": 27.0, "to": 30.0}]
const GROUPS := [
	{"id": "night", "label": "THE NIGHT", "fields": ["who", "where", "when"]},
	{"id": "act", "label": "THE ACT", "fields": ["who", "how"]},
	{"id": "reason", "label": "THE REASON", "fields": ["who", "why"]}]
const FIELDS := ["who", "when", "where", "how", "why"]
const MOTIVES := {"grudge": "An old grudge", "money": "Money", "family": "Inheritance", "silence": "To keep a secret", "passion": "Jealousy"}
const METHODS := {"blunt": "A blow to the head", "knife": "A knife", "strangle": "Strangulation", "poison": "Poison"}
const CHARGES := {"murder": "Murder", "killing": "Unlawful killing", "held": "Held on suspicion", "unconfirmed": "Charge on your own judgement", "none": "No charge yet"}
const SENTENCE := {"murder": 25, "killing": 18, "held": 10}
const SPEED := 15.0            # metres a minute on foot, as everywhere else


static func blank() -> Dictionary:
	return {"who": "", "when": "", "where": "", "how": "", "why": "",
		"cites": {"who": [], "when": [], "where": [], "how": [], "why": []},
		"stamps": {"night": "open", "act": "open", "reason": "open"}, "checks": 0}


static func ensure(det: RefCounted) -> Dictionary:
	if det.sheet.is_empty():
		det.sheet = blank()
	return det.sheet


static func band(id: String) -> Dictionary:
	for b in BANDS:
		if b["id"] == id:
			return b
	return {}


static func band_of_hour(h: float) -> String:
	for b in BANDS:
		if h >= float(b["from"]) and h < float(b["to"]):
			return String(b["id"])
	return "dawn" if h >= 30.0 else "eve"


static func group_complete(sh: Dictionary, gid: String) -> bool:
	for g in GROUPS:
		if g["id"] == gid:
			for f in g["fields"]:
				if String(sh.get(f, "")) == "":
					return false
			return true
	return false


# ------------------------------------------------------------------ the claims you cite
## Every claim in the notebook by its opaque id: {claim, eid, title}.
static func index(det: RefCounted) -> Dictionary:
	var out := {}
	for eid in det.order:
		var e: Dictionary = det.known[eid]
		for cl in e.get("claims", []):
			out[String(cl.get("cid", ""))] = {"claim": cl, "eid": String(eid), "title": String(e.get("title", ""))}
	return out


static func cited(det: RefCounted, sh: Dictionary, fields: Array, keep: Callable = Callable()) -> Array:
	var idx: Dictionary = index(det)
	var seen := {}
	var out: Array = []
	for f in fields:
		for cid in sh["cites"].get(f, []):
			if idx.has(cid) and not seen.has(cid):
				seen[cid] = true
				if not keep.is_valid() or keep.call(idx[cid]["claim"]):
					out.append(idx[cid]["claim"])
	return out


static func _entries(claims: Array, notebook: Array) -> Array:
	var cl: Array = claims.duplicate()
	for e in notebook:       # the time of death belongs to the case; it frames the cited claims without being one of them
		for c in e.get("claims", []):
			if String(c.get("predicate", "")) in ["time_of_death", "weapon_on_grounds", "known_for", "odd_detail"]:
				cl.append(c)
	return [{"claims": cl}]


static func _overlaps(cl: Dictionary, lo: float, hi: float) -> bool:
	var t: float = float(cl.get("time", -1.0))
	if t < 0.0:
		return false
	var u: float = float(cl.get("until", -1.0))
	if u < 0.0:
		u = t
	return t <= hi and u >= lo


## Do the cited claims establish each group, by the rules of evidence? `c` (the private truth) is passed only at adjudication, to drop the
## claims that are false or misleading; the notebook-only read (c empty) is what the player's own screens could compute.
static func support(det: RefCounted, case_file: Dictionary, jobs: Dictionary, sh: Dictionary, c: Dictionary = {}) -> Dictionary:
	var out := {"night": false, "act": false, "reason": false}
	var who: String = String(sh.get("who", ""))
	if who == "":
		return out
	var keep := func(cl: Dictionary) -> bool: return c.is_empty() or Claims.tag_of(c, cl) == "true"
	var nb: Array = Reasoning.entries_of(det.known)
	var win: Array = Reasoning.death_window(nb)
	# the night: someone placed out near the hour, the body's own time, and a place
	var nc: Array = cited(det, sh, ["who", "where", "when"], keep)
	var pn: Dictionary = Reasoning.proof_against(_entries(nc, nb), case_file, who, jobs)
	var who_ok: bool = int(pn["opportunity"]) + int(pn["link"]) >= 2 and int(pn["exonerate"]) < 3
	var b: Dictionary = band(String(sh.get("when", "")))
	var when_ok := false
	if not b.is_empty():
		var has_tod := nc.any(func(cl): return String(cl.get("predicate", "")) == "time_of_death")
		var in_window: bool = float(win[0]) <= float(b["to"]) + 0.25 and float(win[1]) >= float(b["from"]) - 0.25
		var timed := nc.any(func(cl): return String(cl.get("subject", "")) == who and Reasoning.RULES.has(String(cl.get("predicate", ""))) and _overlaps(cl, float(b["from"]) - 0.75, float(b["to"]) + 0.75))
		when_ok = has_tod and in_window and (timed or int(pn["link"]) >= 2)
	var where: String = String(sh.get("where", ""))
	var where_ok: bool = where != "" and nc.any(func(cl): return String(cl.get("place", "")) == where)
	out["night"] = who_ok and when_ok and where_ok
	# the act: the wound the body shows, and a means in this person's hands
	var ac: Array = cited(det, sh, ["who", "how"], keep)
	var pa: Dictionary = Reasoning.proof_against(_entries(ac, nb), case_file, who, jobs)
	var how_ok: bool = String(sh.get("how", "")) != "" and ac.any(func(cl): return String(cl.get("predicate", "")) == "cause_of_death" and String(cl.get("item", "")) == String(sh["how"]))
	out["act"] = how_ok and int(pa["means"]) >= 1 and int(pa["exonerate"]) < 3
	# the reason: what the documents and the witnesses say this person wanted
	var rc: Array = cited(det, sh, ["who", "why"], keep)
	var pr: Dictionary = Reasoning.proof_against(_entries(rc, nb), case_file, who, jobs)
	var why: String = String(sh.get("why", ""))
	out["reason"] = why != "" and int(pr["motive"]) >= 2 and Reasoning.motive_guess(_entries(rc, nb), who) == why and int(pr["exonerate"]) < 3
	return out


## Is the answer actually so? (Adjudication only.) The hour may be half an hour out at a band's edge: clocks are never exact.
static func correct(c: Dictionary, sh: Dictionary) -> Dictionary:
	var k: bool = String(sh.get("who", "")) == String(c.get("killer", "#"))
	var b: Dictionary = band(String(sh.get("when", "")))
	var h: float = float(c.get("hour", 0.0))
	var when_ok: bool = not b.is_empty() and h >= float(b["from"]) - 0.5 and h < float(b["to"]) + 0.5
	return {"night": k and String(sh.get("where", "")) == String(c.get("scene", "#")) and when_ok,
		"act": k and String(sh.get("how", "")) == String(c.get("method", "#")),
		"reason": k and String(sh.get("why", "")) == String(c.get("motive", "#"))}


## The stamps: confirmed only where the group is jointly correct and supported by claims that are themselves true.
static func adjudicate(det: RefCounted, case_file: Dictionary, jobs: Dictionary, sh: Dictionary, c: Dictionary) -> Dictionary:
	var sup: Dictionary = support(det, case_file, jobs, sh, c)
	var cor: Dictionary = correct(c, sh)
	var stamps := {}
	for g in GROUPS:
		var gid: String = g["id"]
		if not group_complete(sh, gid):
			stamps[gid] = "open"
		elif bool(sup[gid]) and bool(cor[gid]):
			stamps[gid] = "confirmed"
		else:
			stamps[gid] = "unsupported"
	return stamps


## What the confirmed groups allow. Murder needs all three, unlawful killing the night and one more, a hold on suspicion any one.
static func charge_level(stamps: Dictionary, pattern: bool = false) -> String:
	var n := 0
	for k in stamps:
		if stamps[k] == "confirmed":
			n += 1
	if pattern and stamps.get("night", "") == "confirmed" and stamps.get("act", "") == "confirmed":
		return "murder"       # the same sign at more than one scene stands in for a motive nobody can know
	if n >= 3:
		return "murder"
	if stamps.get("night", "") == "confirmed" and n >= 2:
		return "killing"
	if n >= 1:
		return "held"
	return "unconfirmed"


## Has the same unexplained detail turned up at more than one scene in your notebook? (A serial killer's sign.)
static func pattern(det: RefCounted) -> bool:
	var seen := {}
	for e in det.known.values():
		for cl in e.get("claims", []):
			if String(cl.get("predicate", "")) == "odd_detail" and String(cl.get("item", "")) != "":
				seen[String(cl["item"])] = int(seen.get(String(cl["item"]), 0)) + 1
	for k in seen:
		if int(seen[k]) >= 2:
			return true
	return false


static func answered(sh: Dictionary) -> int:
	var n := 0
	for f in FIELDS:
		if String(sh.get(f, "")) != "":
			n += 1
	return n


# ------------------------------------------------------------------ test the theory
## Check the sheet against everything recorded in the notebook and return only the contradictions that can be found there: an alibi that
## covers the hour, a time that is not the body's, a recording that puts them somewhere they could not have left in time, two claims that
## cannot both stand, a cite that rests on a hedging witness, another name the notes cannot tell apart. Never the answer.
static func test_theory(sim: RefCounted, det: RefCounted, case_file: Dictionary, jobs: Dictionary, sh: Dictionary, by_id: Dictionary, names: Callable) -> Dictionary:
	var lines: Array = []
	var who: String = String(sh.get("who", ""))
	if who == "":
		return {"lines": ["There is no name on the sheet to test."], "count": 0}
	var nb: Array = Reasoning.entries_of(det.known)
	var win: Array = Reasoning.death_window(nb)
	var nm: String = String(names.call(who))
	var b: Dictionary = band(String(sh.get("when", "")))
	var lo: float = float(b["from"]) if not b.is_empty() else float(win[0])
	var hi: float = float(b["to"]) if not b.is_empty() else float(win[1])
	if not b.is_empty() and not (float(win[0]) <= hi + 0.25 and float(win[1]) >= lo - 0.25):
		lines.append("The body's own time (%s to %s) does not touch the hour you have written." % [_clock(float(win[0])), _clock(float(win[1]))])
	var where: String = String(sh.get("where", ""))
	for e in nb:
		for cl in e.get("claims", []):
			if String(cl.get("subject", "")) != who:
				continue
			var pred: String = String(cl.get("predicate", ""))
			var title: String = String(e.get("title", "a note"))
			if pred == "elsewhere" and _overlaps(cl, maxf(lo, float(win[0])), minf(hi, float(win[1]))):
				lines.append("%s is on record as somewhere else in that stretch (%s)." % [nm, title])
			elif pred == "left_before_death" and float(cl.get("time", 99.0)) < float(win[0]) + 0.75:
				lines.append("%s is on record as having left before the death (%s)." % [nm, title])
			elif pred in ["arrived_at", "seen_out_at_night", "tagged_on_tape", "seen_at_scene", "left_from"] and where != "" and String(cl.get("place", "")) not in ["", where]:
				var t: float = float(cl.get("time", -1.0))
				if t >= float(win[0]) and t <= float(win[1]) and by_id.has(String(cl["place"])) and by_id.has(where):
					var a: Dictionary = by_id[String(cl["place"])]
					var z: Dictionary = by_id[where]
					var mins: float = Vector2(float(a["x"]), float(a["y"])).distance_to(Vector2(float(z["x"]), float(z["y"]))) / SPEED
					if t + mins / 60.0 > float(win[1]) + 0.25:
						lines.append("%s was recorded at %s at %s (%s). From there they could not have been at the place you have written by the time it was over." % [nm, _place(by_id, String(cl["place"])), _clock(t), title])
	for k in Reasoning.contradictions(det.known, case_file):
		if String(k["who"]) == who:
			lines.append("%s %s." % [nm, String(k["why"])])
	# a cite that rests on a hedge
	var shaky := 0
	for cl in cited(det, sh, FIELDS):
		if Reasoning.doubt_of(cl) != "":
			shaky += 1
	if shaky > 0:
		lines.append("%d of the claims you cite %s soft: a witness who hedged, footage that is poor, a print that is only partial." % [shaky, "is" if shaky == 1 else "are"])
	# someone the notes cannot tell apart
	var mine: Dictionary = Reasoning.proof_against(det.known, case_file, who, jobs)
	var mine_n: int = int(mine["opportunity"]) + int(mine["link"])
	var rivals: Array = []
	for s in Reasoning.people_named(det.known):
		if s == who or s == String(case_file.get("victim", "")) or s == "player" or not sim.people.has(s):
			continue
		var p: Dictionary = Reasoning.proof_against(det.known, case_file, s, jobs)
		if int(p["exonerate"]) < 3 and int(p["opportunity"]) + int(p["link"]) >= maxi(mine_n, 3):
			rivals.append(String(names.call(s)))
	if not rivals.is_empty():
		lines.append("Your notes do not separate %s from %s: both are placed near the hour and nothing clears either." % [nm, Prose.list_join(rivals.slice(0, 3))])
	return {"lines": lines, "count": lines.size()}


static func _clock(h: float) -> String:
	var hh: int = int(floor(fposmod(h, 24.0)))
	var mm: int = int(round((h - floor(h)) * 60.0))
	if mm == 60:
		hh = (hh + 1) % 24
		mm = 0
	var ap := "am" if hh < 12 else "pm"
	var h12: int = hh % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, ap]


static func _place(by_id: Dictionary, lot: String) -> String:
	return String(by_id[lot]["name"]) if by_id.has(lot) else "somewhere else"
