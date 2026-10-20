extends RefCounted
## Talking to people in someone else's body. Every line is built from the sim: how they feel about the person they think you
## are, their mood, their needs, their job, their hobby. Same words never come out the same way twice for two different people.

const Data = preload("res://scripts/core/data.gd")

const TOPICS := [
	{"id": "chat", "label": "Small talk"},
	{"id": "ask_day", "label": "\"How's your day?\""},
	{"id": "compliment", "label": "Pay a compliment"},
	{"id": "joke", "label": "Tell a joke"},
	{"id": "gossip", "label": "\"Heard anything?\""},
	{"id": "confide", "label": "\"What's really going on?\""},
	{"id": "favor", "label": "Ask to borrow 20"},
	{"id": "argue", "label": "Pick a fight"}]


static func tier(sim: RefCounted, npc: RefCounted, host_id: String, salt: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash("talk|%d|%d|%s|%s|%s" % [sim.seed_base, sim.day * 100 + sim.clock, npc.id, host_id, salt])
	var s: float = npc.affinity(host_id) / 100.0 + (npc.mood() - 50.0) / 160.0 + npc.trust(host_id) / 300.0 + r.randf_range(-0.2, 0.2)
	return "warm" if s > 0.3 else ("neutral" if s > -0.05 else "cold")


static func _pick(options: Array, sim: RefCounted, npc: String, salt: String) -> String:
	return String(options[hash("%d|%d|%s|%s" % [sim.seed_base, sim.day * 100 + sim.clock, npc, salt]) % options.size()])


static func state_word(p: RefCounted) -> String:
	var n: Dictionary = p.needs
	if float(n["restless"]) >= 75.0: return "restless"
	if float(n["energy"]) < 25.0: return "exhausted"
	if float(n["hunger"]) < 25.0: return "starving"
	if p.money < 25.0 and p.job != "student" and p.group != "child": return "broke"
	if float(n["social"]) < 25.0: return "lonely"
	if float(n["fun"]) < 25.0: return "bored"
	return "ok"


## Say something. Returns {text, tone, ok, learned?} and changes the relationship, needs and rumour mill.
static func say(sim: RefCounted, host_id: String, npc_id: String, topic: String) -> Dictionary:
	var cfg: Dictionary = Data.load_json("sim/talk.json")
	var npc: RefCounted = sim.people[npc_id]
	var host: RefCounted = sim.people[host_id]
	var t := tier(sim, npc, host_id, topic)
	var res := {"text": "", "tone": t, "ok": true, "topic": topic}
	match topic:
		"chat":
			var line := _pick(cfg["chat"][t], sim, npc_id, "chat")
			if t != "cold":
				if npc.hobby != "" and hash(npc_id + str(sim.day)) % 2 == 0:
					line += " " + String(cfg["hobby_chat"].get(npc.hobby, "")).replace("{fishing_mood}", "strange")
				else:
					line += " " + String(cfg["job_chat"].get(npc.job, cfg["job_chat"]["other"]))
			res["text"] = line
			sim.player_act(host_id, "socialize", {"target": npc_id})
			if t == "cold":
				npc.bump(host_id, -1.0, 0.0)
		"ask_day":
			var st: String = state_word(npc)
			res["text"] = _pick(cfg["ask_day"][t], sim, npc_id, "day").replace("{state}", String(cfg["state"][st]) if t != "cold" else "")
			res["learned"] = st
			if t != "cold":
				npc.bump(host_id, 1.0, 1.0)
		"compliment":
			res["text"] = _pick(cfg["compliment"][t], sim, npc_id, "comp")
			if t == "cold":
				res["ok"] = false
			sim.player_act(host_id, "praise", {"target": npc_id})
		"joke":
			res["text"] = _pick(cfg["joke"][t], sim, npc_id, "joke")
			if t == "cold":
				res["ok"] = false
				npc.bump(host_id, -3.0, 0.0)
			else:
				npc.needs["fun"] = clampf(float(npc.needs["fun"]) + 6.0, 0.0, 100.0)
				npc.bump(host_id, 2.0, 0.0)
		"gossip":
			var heard := ""
			if t != "cold":
				for ru in sim.rumors:
					if float(ru["belief"].get(npc_id, 0.0)) >= 45.0 and ru["subject"] != npc_id:
						heard = String(ru["claim"])
						res["learned"] = ru["id"]
						break
			if t == "cold":
				res["text"] = _pick(cfg["gossip"]["cold"], sim, npc_id, "g")
				res["ok"] = false
			elif heard == "":
				res["text"] = _pick(cfg["gossip"]["none"], sim, npc_id, "g")
			else:
				res["text"] = _pick(cfg["gossip"][t], sim, npc_id, "g").replace("{rumor}", heard)
		"confide":
			if t == "cold" or npc.trust(host_id) < 25.0:
				res["text"] = _pick(cfg["confide"]["cold"], sim, npc_id, "c")
				res["ok"] = false
			else:
				var w := _worry_for(npc)
				res["text"] = _pick(cfg["confide"][t if cfg["confide"].has(t) else "neutral"], sim, npc_id, "c").replace("{worry}", w)
				res["learned"] = state_word(npc)
				npc.bump(host_id, 2.0, 4.0)
		"favor":
			if t != "cold" and npc.affinity(host_id) >= 25.0 and npc.money >= 80.0:
				npc.money -= 20.0
				host.money += 20.0
				npc.bump(host_id, -1.0, 0.0)
				npc.remember(sim.day, host_id, "lent me money", 0.4)
				res["text"] = _pick(cfg["favor_yes"], sim, npc_id, "f")
			else:
				res["ok"] = false
				res["text"] = _pick(cfg["favor_no"], sim, npc_id, "f")
		"argue":
			res["text"] = _pick(cfg["argue"]["any"], sim, npc_id, "a")
			res["ok"] = false
			sim.player_act(host_id, "insult", {"target": npc_id})
	return res


static func _worry_for(p: RefCounted) -> String:
	match state_word(p):
		"restless": return "I keep thinking about just walking out. Leaving all of it."
		"exhausted": return "I'm running on nothing. I can't keep this up."
		"starving": return "I've been skipping meals. Money, mostly."
		"broke": return "I don't know how I'm going to cover this month."
		"lonely": return "Some days nobody speaks to me from morning till night."
		"bored": return "Every day's the same. I feel like I'm fading."
	return "Honestly? I'm fine. Better than fine. It scares me a little."
