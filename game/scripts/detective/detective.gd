extends RefCounted
## You: the lead (and only) detective. Skills gate how much you perceive, never whether you can finish. Stress frays them.
## The notebook is everything you have learned; it resists the Hush, so it is the one record in Little Mercy that cannot be edited.

const SKILLS := ["observation", "empathy", "authority", "charm", "logic", "forensics", "occult", "streetwise"]
const LABELS := {"observation": "Observation", "empathy": "Empathy", "authority": "Authority", "charm": "Charm", "logic": "Logic",
	"forensics": "Forensics", "occult": "Occult", "streetwise": "Streetwise"}
const XP_PER_LEVEL := 100

var name := "Detective"
var skills: Dictionary = {"observation": 3, "empathy": 3, "authority": 3, "charm": 3, "logic": 3, "forensics": 3, "occult": 2, "streetwise": 3}
var xp := 0
var level := 1
var points := 0                     # skill points to spend
var stress := 0.0                   # 0-100
var tools: Array = ["notebook", "camera", "evidence kit", "fingerprint kit"]
var known: Dictionary = {}          # entry id -> entry
var order: Array = []               # entry ids in the order learned
var statements: Array = []          # [{day, npc, topic, text}]
var warrants: Dictionary = {}       # person id -> true
var lab: Array = []                 # [{clue, ready_day}]
var lab_done: Array = []
var told: Dictionary = {}           # "npc|fact" -> true (never repeat the same answer)
var calibrated: Dictionary = {}     # camera id -> true once its clock has been checked
var samples: Dictionary = {}        # person id -> true once their fingerprints are on file
var reputation: Dictionary = {"sheriff": 0, "town": 0, "chapel": 0}
var cases_solved := 0
var cases_failed := 0


func skill(s: String) -> int:
	var v: int = int(skills.get(s, 1))
	if stress >= 70.0:
		v -= 1
	if stress >= 90.0:
		v -= 1
	return maxi(v, 0)


## A passive check: you pass if your skill meets the difficulty. One short and you get a partial read.
func check(s: String, difficulty: int) -> String:
	var have := skill(s)
	if have >= difficulty:
		return "pass"
	if have == difficulty - 1:
		return "partial"
	return "fail"


func gain_xp(n: int) -> bool:
	xp += n
	var leveled := false
	while xp >= level * XP_PER_LEVEL:
		xp -= level * XP_PER_LEVEL
		level += 1
		points += 2
		leveled = true
	return leveled


func spend_point(s: String) -> bool:
	if points <= 0 or int(skills[s]) >= 10:
		return false
	points -= 1
	skills[s] = int(skills[s]) + 1
	return true


func add_stress(n: float) -> void:
	stress = clampf(stress + n, 0.0, 100.0)


func learn(entry: Dictionary) -> bool:
	if known.has(entry["id"]):
		return false
	known[entry["id"]] = entry
	order.append(entry["id"])
	return true


func has(id: String) -> bool:
	return known.has(id)


## What the notebook says about one person, by category: {opportunity, means, motive, link, exonerate} -> strength.
func proof_against(id: String) -> Dictionary:
	var out := {"opportunity": 0, "means": 0, "motive": 0, "link": 0, "exonerate": 0}
	for eid in known:
		for sup in known[eid].get("supports", []):
			if sup["about"] == id and out.has(sup["cat"]):
				out[sup["cat"]] = int(out[sup["cat"]]) + int(sup["strength"])
	return out


func to_dict() -> Dictionary:
	return {"name": name, "skills": skills.duplicate(), "xp": xp, "level": level, "points": points, "stress": stress, "tools": tools.duplicate(),
		"known": known.duplicate(true), "order": order.duplicate(), "statements": statements.duplicate(true), "warrants": warrants.duplicate(),
		"lab": lab.duplicate(true), "lab_done": lab_done.duplicate(), "told": told.duplicate(), "calibrated": calibrated.duplicate(), "samples": samples.duplicate(), "rep": reputation.duplicate(), "solved": cases_solved, "failed": cases_failed}


static func from_dict(d: Dictionary) -> RefCounted:
	var x: RefCounted = load("res://scripts/detective/detective.gd").new()
	if d.is_empty():
		return x
	x.name = d.get("name", "Detective")
	x.skills = d.get("skills", x.skills).duplicate()
	for k in x.skills:
		x.skills[k] = int(x.skills[k])
	x.xp = int(d.get("xp", 0)); x.level = int(d.get("level", 1)); x.points = int(d.get("points", 0)); x.stress = float(d.get("stress", 0.0))
	x.tools = d.get("tools", x.tools).duplicate()
	x.known = d.get("known", {}).duplicate(true)
	x.order = d.get("order", []).duplicate()
	x.statements = d.get("statements", []).duplicate(true)
	x.warrants = d.get("warrants", {}).duplicate()
	x.lab = d.get("lab", []).duplicate(true)
	x.lab_done = d.get("lab_done", []).duplicate()
	x.told = d.get("told", {}).duplicate()
	x.calibrated = d.get("calibrated", {}).duplicate()
	x.samples = d.get("samples", {}).duplicate()
	x.reputation = d.get("rep", x.reputation).duplicate()
	x.cases_solved = int(d.get("solved", 0)); x.cases_failed = int(d.get("failed", 0))
	return x
