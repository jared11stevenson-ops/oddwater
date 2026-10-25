extends RefCounted
## You: the lead (and only) detective. Skills gate how much you perceive, never whether you can finish. Stress frays them.
## The notebook is everything you have learned; it resists the Hush, so it is the one record in Little Mercy that cannot be edited.
## Its entries hold CLAIMS (see claims.gd), never conclusions: what a proof is worth is worked out by Reasoning, from the claims alone.

const Reasoning = preload("res://scripts/detective/reasoning.gd")

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
var rep_log: Array = []             # every change to the three standings, newest last: [{day, event, d}]
var asked: Dictionary = {}          # "npc|topic|about" -> how many times (a repeat question gets a different reply)
var rank := "Detective"             # the state police can reassign you after a failure
var funerals: Dictionary = {}       # case id -> true once you have attended
var flagged: Dictionary = {}        # person id -> true: people you have chosen to keep an eye on
var board: Dictionary = {"pos": {}, "links": []}   # the evidence board: card positions (0..1) and the strings YOU drew: [a, b, kind]; your theory, not the truth
var visited: Dictionary = {}        # lot id -> true once you have stood at its door (fast travel remembers them)
var ctx: Dictionary = {"case": {}, "jobs": {}}   # the public case file and the town's trades, set by the game (not saved: it is rebuilt)


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


## A new case begins and the old one stays open: its entries move under a prefix (so the old scene is not mistaken for the new),
## but what they prove about a person still counts. Fingerprints on file and the notebook stay with you.
func rollover(prefix: String) -> void:
	var nk: Dictionary = {}
	var no: Array = []
	for eid in order:
		var e: Dictionary = known[eid].duplicate(true)
		var nid := "%s:%s" % [prefix, eid]
		e["id"] = nid
		e["old_case"] = prefix
		nk[nid] = e
		no.append(nid)
	known = nk
	order = no
	lab = []
	told = {}
	asked = {}
	calibrated = {}
	warrants = {}


func has(id: String) -> bool:
	return known.has(id)


## What the notebook says about one person, by category: {opportunity, means, motive, link, exonerate} -> strength (see Reasoning).
func proof_against(id: String) -> Dictionary:
	return Reasoning.proof_against(known, ctx.get("case", {}), id, ctx.get("jobs", {}))


## The DA's read of the case against one person, from the notebook alone.
func da_read(id: String, person_name: String = "") -> String:
	return Reasoning.da_read(known, ctx.get("case", {}), id, ctx.get("jobs", {}), person_name)


func flag_person(id: String) -> void:
	flagged[id] = true


func visit(lot: String) -> void:
	if lot != "":
		visited[lot] = true


## Draw (or erase, if it is already there) a string between two cards on the board. Returns true if the string now exists.
func link(a: String, b: String, kind: String = "theory") -> bool:
	for i in board["links"].size():
		var l: Array = board["links"][i]
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			board["links"].remove_at(i)
			return false
	board["links"].append([a, b, kind])
	return true


## Everyone the notebook gives a reason to look at: the one who found the body, anyone named by a claim, anyone you have questioned
## or flagged. Nothing here knows who did it; the game filters out the dead and the gone.
func persons_of_interest() -> Array:
	var out: Array = []
	var add := func(id: String) -> void:
		if id != "" and id != "player" and id != String(ctx.get("case", {}).get("victim", "")) and not out.has(id):
			out.append(id)
	add.call(String(ctx.get("case", {}).get("found_by", "")))
	for id in Reasoning.people_named(known):
		add.call(String(id))
	for st in statements:
		if String(st.get("topic", "")) != "present":
			add.call(String(st["npc"]))
	for id in flagged:
		add.call(String(id))
	return out


## An old notebook entry (from before claims) keeps what it was worth as a legacy claim, so a saved game still adds up.
static func _migrate(e: Dictionary) -> Dictionary:
	if e.has("claims") and not e.has("supports"):
		return e
	var claims: Array = []
	for sup in e.get("supports", []):
		if String(sup.get("cat", "")) in ["opportunity", "means", "motive", "link", "exonerate"] and String(sup.get("about", "")) != "":
			claims.append({"kind": "said", "subject": String(sup["about"]), "predicate": "legacy_" + String(sup["cat"]), "place": "", "time": -1.0, "until": -1.0,
				"item": str(int(sup.get("strength", 1))), "certainty": 1.0, "source": String(e.get("source", "")), "text": String(e.get("text", "")), "cid": "legacy"})
	if claims.is_empty():
		claims.append({"kind": "found", "subject": "", "predicate": "observation", "place": "", "time": -1.0, "until": -1.0, "item": "", "certainty": 1.0, "source": String(e.get("source", "")), "text": String(e.get("text", "")), "cid": "legacy"})
	e["claims"] = claims
	e.erase("supports")
	for k in ["unreliable", "misleading", "has_detail", "false_confession"]:
		e.erase(k)
	return e


func to_dict() -> Dictionary:
	return {"name": name, "skills": skills.duplicate(), "xp": xp, "level": level, "points": points, "stress": stress, "tools": tools.duplicate(),
		"known": known.duplicate(true), "order": order.duplicate(), "statements": statements.duplicate(true), "warrants": warrants.duplicate(),
		"lab": lab.duplicate(true), "lab_done": lab_done.duplicate(), "told": told.duplicate(), "calibrated": calibrated.duplicate(), "samples": samples.duplicate(), "rep": reputation.duplicate(), "solved": cases_solved, "failed": cases_failed,
		"rep_log": rep_log.duplicate(true), "asked": asked.duplicate(), "rank": rank, "funerals": funerals.duplicate(), "flagged": flagged.duplicate(),
		"board": board.duplicate(true), "visited": visited.duplicate()}


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
	for kid in x.known:
		x.known[kid] = _migrate(x.known[kid])
	x.flagged = d.get("flagged", {}).duplicate()
	x.board = d.get("board", {"pos": {}, "links": []}).duplicate(true)
	x.visited = d.get("visited", {}).duplicate()
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
	x.rep_log = d.get("rep_log", []).duplicate(true)
	x.asked = d.get("asked", {}).duplicate()
	x.rank = String(d.get("rank", "Detective"))
	x.funerals = d.get("funerals", {}).duplicate()
	for k in x.reputation:
		x.reputation[k] = int(x.reputation[k])
	return x
