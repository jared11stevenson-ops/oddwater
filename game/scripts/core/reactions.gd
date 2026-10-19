extends RefCounted
## The reactivity layer: what a person brings up when you walk up to them, read from the living town.
## Pure and deterministic. A reaction is {kind, text, tone, suspicion}. The same sim state always gives the same opener.

const Data = preload("res://scripts/core/data.gd")

const MAX_LINES := 3


static func _pick(options: Array, salt: String, day: int) -> String:
	return String(options[(salt.hash() + day) % options.size()])


## "saw Mags Pell steal" and "saw Jo Marsh steal" are the same memory.
static func _key(what: String) -> String:
	return "saw %s steal" if what.begins_with("saw ") and what.ends_with(" steal") else what


## Openers for `npc` meeting the player in the body of `host`. `sim` is the SimWorld.
static func openers(sim: RefCounted, npc: String, host: String, day: int) -> Array:
	var out: Array = []
	if sim == null or not sim.people.has(npc) or not sim.people.has(host) or npc == host:
		return out
	var cfg: Dictionary = Data.load_json("reactions.json")
	var p: RefCounted = sim.people[npc]

	# 1. a memory of what this host did (the heaviest, most recent one wins)
	var best: Dictionary = {}
	var best_score := -1.0
	for m in p.memories:
		if m["who"] != host or not cfg["memory"].has(_key(String(m["what"]))):
			continue
		var score: float = float(m["weight"]) + 0.01 * int(m["day"])
		if score >= best_score:
			best = m
			best_score = score
	if not best.is_empty():
		var def: Dictionary = cfg["memory"][_key(String(best["what"]))]
		out.append({"kind": "memory", "text": _pick(def["line"], npc + host, day), "tone": def["tone"], "suspicion": int(def["suspicion"])})

	# 2. a rumour they believe, about the person they think you are
	for ru in sim.rumors:
		if ru["subject"] == host and float(ru["belief"].get(npc, 0.0)) >= 50.0 and ru["origin"] != npc:
			out.append({"kind": "rumor", "text": _pick(cfg["rumor"]["believed"], npc, day) % ru["claim"], "tone": "wary", "suspicion": 4 + int(ru["severity"]) * 2})
			break

	# 3. gossip about somebody else, if they're the sociable sort
	if out.size() < 2 and p.trait_of("sociable") >= 0.55:
		for ru in sim.rumors:
			if ru["subject"] != host and ru["subject"] != npc and float(ru["belief"].get(npc, 0.0)) >= 50.0:
				out.append({"kind": "gossip", "text": _pick(cfg["rumor"]["gossip"], npc, day) % ru["claim"], "tone": "chatty", "suspicion": 0})
				break

	# 4. somebody who is gone, that this person was close to
	for id in sim.order:
		var q: RefCounted = sim.people[id]
		if (q.struck or q.taken) and id != host and p.affinity(id) >= 30.0:
			out.append({"kind": "vacancy", "text": _pick(cfg["vacancy"], npc, day) % q.display, "tone": "sad", "suspicion": 0})
			break

	# 5. body language: mood and money (aside, no suspicion)
	var mood_line: String = cfg["mood"].get(p.mood_word(), "")
	if mood_line != "":
		out.append({"kind": "mood", "text": mood_line, "tone": "aside", "suspicion": 0})
	if p.money < 40.0 and cfg["money"]["broke"] != "":
		out.append({"kind": "money", "text": cfg["money"]["broke"], "tone": "aside", "suspicion": 0})

	return out.slice(0, MAX_LINES)
