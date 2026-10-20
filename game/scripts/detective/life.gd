extends RefCounted
## Ordinary days. Between murders Little Mercy goes on: a missing cat, a stolen bicycle, a noise complaint, a number scrawled on a wall.
## Small cases with two witnesses each; solving them earns a little standing, texture, and a reminder of how the town talks.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Prose = preload("res://scripts/detective/prose.gd")

const PETS := ["a grey tabby called Biscuit", "a one-eared dog called Admiral", "a parrot called Deacon", "a rabbit called Mrs Pettigrew"]


static func _r(seed_v: int, day: int, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|biz|%d|%s" % [seed_v, day, salt])
	return r


## Maybe a piece of town business for today. Returns {} on a day with none.
static func roll(sim: RefCounted, seed_v: int, day: int, open_ids: Array) -> Dictionary:
	var r := _r(seed_v, day, "roll")
	if r.randf() > 0.7:
		return {}
	var adults: Array = CaseEngine._adults(sim)
	if adults.size() < 6:
		return {}
	var who: String = adults[r.randi() % adults.size()]
	var near: Array = CaseEngine.neighbors(sim, sim.people[who].home, 4, [who])
	var culprit_pool: Array = sim.order.filter(func(id): return sim.alive(sim.people[id]) and sim.people[id].group in ["teen", "adult"] and id != who and id != "player" and sim.people[id].home != "")
	var culprit: String = culprit_pool[r.randi() % culprit_pool.size()]
	var kind: String = ["pet", "theft", "noise", "wall"][r.randi() % 4]
	var wn := CaseEngine.first(sim, who)
	var cn := CaseEngine.first(sim, culprit)
	var b := {"id": "biz_%d" % day, "kind": kind, "complainant": who, "culprit": culprit, "day": day, "expires": day + 5, "status": "open", "need": 2, "found": [], "leads": []}
	var l1: String = near[0] if near.size() > 0 else who
	var l2: String = near[1] if near.size() > 1 else who
	match kind:
		"pet":
			var pet: String = PETS[r.randi() % PETS.size()]
			var shed := CaseEngine.name_of(sim, culprit)
			b["title"] = "Missing: %s" % pet
			b["report"] = "%s has lost %s. It got out on Tuesday and nobody has seen it since." % [sim.people[who].display, pet]
			b["leads"] = [{"npc": l1, "text": "I heard scratching in %s's shed all yesterday. I thought it was rats." % shed}, {"npc": l2, "text": "I saw %s carrying a basket, covered with a cloth, and it was moving." % cn}]
			b["solution"] = "%s had taken the animal in, thinking it a stray. It is returned with apologies and a cake." % cn
		"theft":
			b["title"] = "Stolen: a bicycle"
			b["report"] = "%s's bicycle was taken from outside the Rising Loaf while %s was inside buying bread." % [sim.people[who].display, wn]
			b["leads"] = [{"npc": l1, "text": "A hooded kid went off on it at a hell of a speed. Red hood. They went toward the green."}, {"npc": l2, "text": "That was %s's bike by the green on Wednesday. I thought it was theirs." % cn}]
			b["solution"] = "%s borrowed it for a day and meant to put it back. It is found, a little muddier, against the Grange wall." % cn
		"noise":
			b["title"] = "Complaint: noise at night"
			b["report"] = "%s has complained of music and banging after midnight, three nights running. Nobody else admits to hearing it." % sim.people[who].display
			b["leads"] = [{"npc": l1, "text": "It isn't music. It's somebody walking in a cellar, in time to something. I don't like it."}, {"npc": l2, "text": "It's %s's cellar. They practise down there so as not to wake the street. They think." % cn}]
			b["solution"] = "%s has been practising the drums in the cellar. A compromise is reached involving blankets and Thursday afternoons." % cn
		_:
			b["title"] = "Vandalism: a number on the wall"
			b["report"] = "Someone has chalked 4:12 on the wall behind the library, fourteen times, in a careful hand. The librarian wants it gone and wants it explained."
			b["leads"] = [{"npc": l1, "text": "Chalk's from the school. The good kind, the thick yellow. Teachers keep it locked up."}, {"npc": l2, "text": "I saw %s there at dusk with chalk on their hands. They said it was a dare. They were white as a sheet." % cn}]
			b["solution"] = "%s did it on a dare, and cannot say who dared them, only that the voice was 'very polite'. You do not write that down." % cn
	return b


static func follow_up(sim: RefCounted, b: Dictionary, npc: String) -> Dictionary:
	if b.get("status", "") != "open":
		return {"text": "That matter is closed.", "minutes": 0, "found": false}
	for l in b["leads"]:
		if l["npc"] == npc:
			if (b["found"] as Array).has(npc):
				return {"text": "%s has told you all they know." % CaseEngine.first(sim, npc), "minutes": 3, "found": false}
			b["found"].append(npc)
			return {"text": "\"%s\"" % l["text"], "minutes": 15, "found": true}
	if npc == b["complainant"]:
		return {"text": "\"%s\" %s says it again, slower, as if that helps." % [b["report"], CaseEngine.first(sim, npc)], "minutes": 10, "found": false}
	return {"text": "%s shrugs. \"Not a thing, I'm afraid.\"" % CaseEngine.first(sim, npc), "minutes": 6, "found": false}
