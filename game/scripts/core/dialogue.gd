extends RefCounted
## Data-driven conversations. Choices change Notes, suspicion and evidence; none can hard-fail the run.

const Data = preload("res://scripts/core/data.gd")
const Reactions = preload("res://scripts/core/reactions.gd")

var state: RefCounted
var convo: Dictionary
var node_id := ""
var finished := false
var tells: Array = []
var claim_defs: Dictionary = {}
var openers: Array = []     # what this person brings up, read from the living town (see reactions.gd)


func start(game_state: RefCounted, file: String, id: String, sim: RefCounted = null) -> Dictionary:
	state = game_state
	convo = Data.load_json("convos/" + file)[id]
	node_id = convo["start"]
	finished = false
	claim_defs = Data.load_json("claims.json")
	openers = Reactions.openers(sim, convo["npc"], state.current_life()["id"], int(state.day)) if sim != null else []
	for o in openers:
		if int(o["suspicion"]) > 0:
			state.suspicion.raise(convo["npc"], int(o["suspicion"]))
		elif int(o["suspicion"]) < 0:
			state.suspicion.calm(convo["npc"], -int(o["suspicion"]))
	_arrive()
	return current()


func current() -> Dictionary:
	return convo["nodes"][node_id]


func choices() -> Array:
	var out: Array = []
	for c in current().get("choices", []):
		var ok := true
		var req: Dictionary = c.get("requires_note", {})
		for k in req:
			if state.notes.get_note(k) < int(req[k]):
				ok = false
		if c.has("requires_seal") and not state.board.seals.has(c["requires_seal"]):
			ok = false
		if ok:
			out.append(c)
	return out


func _apply(effects: Dictionary) -> void:
	for k in effects.get("notes", {}):
		state.notes.add(k, int(effects["notes"][k]))
	if effects.has("lie"):
		state.honesty_pull += int(effects["lie"])
	for npc in effects.get("suspicion", {}):
		state.suspicion.raise(npc, int(effects["suspicion"][npc]))
	if effects.has("evidence"):
		state.board.add_evidence(effects["evidence"])
	if effects.has("tell"):
		tells.append(effects["tell"])


## How a choice sounds: AS YOURSELF (your own voice, always consistent), IN COVER (as the host would),
## or neutral. Authored in the data by `in_character`: false = yourself, true = cover.
func mode_of(c: Dictionary) -> String:
	if state.current_life()["id"] == "player":
		return "self"      # in your own body you are always yourself
	if not c.has("in_character") or c["in_character"] == null:
		return "neutral"
	return "cover" if c["in_character"] else "self"


## The words the player actually sees for a choice: their own voice on self lines.
func display_text(c: Dictionary) -> String:
	if mode_of(c) == "self" and state.persona != null:
		return state.persona.voice(c["text"])
	return c["text"]


## Pick the i-th *available* choice. Returns the next node, or {} when the conversation ends.
func choose(i: int) -> Dictionary:
	if finished:
		return {}
	var cs := choices()
	if i < 0 or i >= cs.size():
		return current()
	_account_mode(cs[i])
	_apply(cs[i])
	node_id = cs[i]["next"]
	# The Honesty Pull: a child can only carry so many fibs. Past the limit the truth falls out.
	if convo.has("blurt") and state.honesty_pull >= 100 and node_id != convo["blurt"] and not current().get("end", false):
		node_id = convo["blurt"]
		state.honesty_pull = 40
	var n := current()
	# node-level effects fire on arrival
	_apply({"suspicion": n.get("suspicion", {})})
	if n.has("evidence"):
		state.board.add_evidence(n["evidence"])
	if n.has("tell"):
		tells.append(n["tell"])
	_arrive_claim(n)
	if n.get("end", false):
		finished = true
	return n


func staged_test(npc: String) -> bool:
	return state.suspicion.stages_test(npc)


func _arrive() -> void:
	_arrive_claim(current())


func _arrive_claim(n: Dictionary) -> void:
	if n.has("claim") and not state.claims.has(n["claim"]):
		state.claims[n["claim"]] = "heard"


## Press the point: show this person a piece of evidence. Works in any body, in any later conversation.
## Returns {result: "crack" | "nothing" | "corrupt", text, claim?}.
func present(evidence_id: String) -> Dictionary:
	var npc: String = convo["npc"]
	if not state.board.evidence.has(evidence_id):
		return {"result": "nothing", "text": "You don't have that."}
	if state.board.is_corrupt(evidence_id):
		state.suspicion.raise(npc, 10)
		return {"result": "corrupt", "text": "They read it. They shake their head. \"That's not what it says.\" (Something is wrong with your card.)"}
	for cid in state.claims:
		var c: Dictionary = claim_defs.get(cid, {})
		if c.is_empty() or c["npc"] != npc or state.claims[cid] != "heard":
			continue
		if c["contradicted_by"].has(evidence_id):
			state.claims[cid] = "cracked"
			state.suspicion.raise(npc, int(c["suspicion"]))
			state.notes.add("candor", 5)
			state.notes.add("nerve", 5)
			if c["reveals"] != "":
				state.board.add_evidence(c["reveals"])
			return {"result": "crack", "text": c["crack"], "claim": cid}
	state.suspicion.raise(npc, 5)
	return {"result": "nothing", "text": "That doesn't prove anything. They look at you a little longer than before."}


## Claims this person has made that you could still contradict (for the UI).
func open_claims() -> Array:
	var out: Array = []
	for cid in state.claims:
		var c: Dictionary = claim_defs.get(cid, {})
		if not c.is_empty() and c["npc"] == convo["npc"] and state.claims[cid] == "heard":
			out.append(cid)
	return out


## Speaking as yourself in a host's company risks an eyebrow, in proportion to how different you sound from them.
## Keeping cover costs nothing now and erodes your sense of self over the day.
func _account_mode(c: Dictionary) -> void:
	var m := mode_of(c)
	if state.current_life()["id"] == "player":
		return
	if m == "self":
		state.self_lines += 1
		state.suspicion.raise(convo["npc"], state.persona.self_risk(state.current_life().get("style", "dry")))
	elif m == "cover":
		state.cover_lines += 1
