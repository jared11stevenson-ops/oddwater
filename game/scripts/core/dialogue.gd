extends RefCounted
## Data-driven conversations. Choices change Notes, suspicion and evidence; none can hard-fail the run.

const Data = preload("res://scripts/core/data.gd")

var state: RefCounted
var convo: Dictionary
var node_id := ""
var finished := false
var tells: Array = []


func start(game_state: RefCounted, file: String, id: String) -> Dictionary:
	state = game_state
	convo = Data.load_json("convos/" + file)[id]
	node_id = convo["start"]
	finished = false
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


## Pick the i-th *available* choice. Returns the next node, or {} when the conversation ends.
func choose(i: int) -> Dictionary:
	if finished:
		return {}
	var cs := choices()
	if i < 0 or i >= cs.size():
		return current()
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
	if n.get("end", false):
		finished = true
	return n


func staged_test(npc: String) -> bool:
	return state.suspicion.stages_test(npc)
