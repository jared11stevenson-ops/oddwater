extends RefCounted
## Voices. Everyone in Little Mercy answers in their own way: the bank of lines is keyed by the speaker's traits (sociable, honest,
## bold, pious, thrift), age group, kind of work and their tie to the dead. A line is never used twice in one case while there is a
## fresh one to give. Also the dread layer: what a frayed detective hears in their own head.

const Data = preload("res://scripts/core/data.gd")
const Prose = preload("res://scripts/detective/prose.gd")

const TRAIT_SHORT := {"sociable": "soc", "honest": "hon", "bold": "bold", "pious": "pious", "thrift": "thrift"}
const SERVICE := ["server", "cook", "dishwasher", "bartender", "bouncer", "baker", "counter", "kitchen", "groomer", "kennel"]
const TRADE := ["boat", "dock", "ferry", "dam", "technician", "inspector", "hardware", "stock", "repairer", "caretaker", "grounds", "stagehand", "bait", "tackle", "funeral"]
const OFFICE := ["clerk", "planner", "records", "council", "librar", "archiv", "producer", "board", "ad sales", "mail", "coordinator", "box office", "costumer", "teacher", "aide", "receptionist", "dispatcher"]
const CARE := ["nurse", "orderly", "care", "hygien"]


static func job_class(job: String) -> String:
	var j := job.to_lower()
	if j == "retired":
		return "retired"
	if j == "student":
		return "student"
	if j in ["unemployed", "odd jobs", ""]:
		return "none"
	for w in CARE:
		if w in j:
			return "care"
	for w in SERVICE:
		if w in j:
			return "service"
	for w in TRADE:
		if w in j:
			return "trade"
	for w in OFFICE:
		if w in j:
			return "office"
	return "office"


static func tags_for(sim: RefCounted, c: Dictionary, npc: String) -> Array:
	var p: RefCounted = sim.people[npc]
	var tags: Array = []
	for k in TRAIT_SHORT:
		var v: float = p.trait_of(k)
		if v >= 0.6:
			tags.append(TRAIT_SHORT[k] + "+")
		elif v <= 0.4:
			tags.append(TRAIT_SHORT[k] + "-")
	tags.append("young" if p.age < 30 else ("old" if p.age >= 62 else "mid"))
	var jc := job_class(p.job)
	tags.append(jc)
	if jc in ["retired", "none"]:
		tags.append("old" if p.age >= 62 else "young")
	var v: String = c.get("victim", "")
	if v != "" and sim.people.has(v):
		if sim.people[v].home == p.home and p.home != "":
			tags.append("kin")
		elif p.work != "" and p.work == sim.people[v].work:
			tags.append("colleague")
		var aff: float = p.affinity(v)
		tags.append("friend" if aff >= 25.0 else ("foe" if aff <= -20.0 else "stranger"))
	return tags


static func _bank(intent: String) -> Array:
	var d: Dictionary = Prose.json("detective/voices.json")
	return d.get(intent, [])


## One line for `intent`, fitted to `npc`. `vars` fills {placeholders}. Remembers what it has said in the case (c["voice_used"]).
static func say(intent: String, sim: RefCounted, c: Dictionary, npc: String, vars: Dictionary = {}) -> String:
	var bank: Array = _bank(intent)
	if bank.is_empty():
		return ""
	var tags: Array = tags_for(sim, c, npc)
	if not c.has("voice_used"):
		c["voice_used"] = {}
	var used: Array = c["voice_used"].get(intent, [])
	var best := -1
	var best_score := -1e9
	for i in bank.size():
		var s := 0.0
		for t in bank[i].get("t", []):
			if tags.has(t):
				s += 10.0
			elif String(t).ends_with("+") and tags.has(String(t).trim_suffix("+") + "-"):
				s -= 6.0
			elif String(t).ends_with("-") and tags.has(String(t).trim_suffix("-") + "+"):
				s -= 6.0
		if bank[i].get("t", []).is_empty():
			s += 2.0
		s += float(absi(hash("%s|%s|%s|%d" % [c.get("id", ""), npc, intent, i])) % 100) / 40.0
		s -= 100.0 * float(used.count(i))
		if s > best_score:
			best_score = s
			best = i
	used.append(best)
	c["voice_used"][intent] = used
	var out: String = bank[best]["s"]
	for k in vars:
		out = out.replace("{%s}" % k, String(vars[k]))
	return out


# =========================================================================== dread
static func intrusive(stress: float, salt: String) -> String:
	var tier := ""
	if stress >= 85.0:
		tier = "high"
	elif stress >= 65.0:
		tier = "mid"
	elif stress >= 45.0:
		tier = "low"
	if tier == "":
		return ""
	var pool: Array = Prose.json("detective/horror.json")["intrusive"][tier]
	return String(pool[absi(hash(salt)) % pool.size()])


## Under heavy stress a result is read twice: the page may swim, and a line of the detective's own head follows the text.
## The notebook keeps the true words; this only changes what the screen shows in the moment.
static func dread(text: String, stress: float, salt: String) -> String:
	var line := intrusive(stress, salt)
	if line == "":
		return text
	# only some results carry one; the rest stay clean so it never becomes noise
	if absi(hash(salt + "|gate")) % 100 >= (35 if stress < 65.0 else (55 if stress < 85.0 else 75)):
		return text
	var out := text
	if stress >= 85.0 and absi(hash(salt + "|swim")) % 3 == 0:
		var re := RegEx.new()
		re.compile("\\d+:\\d\\d")
		var m := re.search(out)
		if m != null:
			out = out.substr(0, m.get_start()) + "?:??" + out.substr(m.get_end()) + "\n(The numbers will not hold still. You check them against the notebook, which can't lie.)"
	return out + "\n\n(" + line + ")"
