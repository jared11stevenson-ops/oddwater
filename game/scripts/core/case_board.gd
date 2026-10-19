extends RefCounted
## Evidence -> Pins -> Links -> Tests -> Seals -> Abilities.
## A Seal needs its Proof Tool (a role/place/day) and any required evidence.

const Data = preload("res://scripts/core/data.gd")

var seal_defs: Dictionary = {}      # id -> def
var ability_defs: Array = []
var evidence: Dictionary = {}       # LF id -> true
var pins: Dictionary = {}           # LF id -> question
var links: Array = []               # [a, b]
var seals: Dictionary = {}          # S id -> day set
var tools_available: Dictionary = {"any": true}


func _init() -> void:
	seal_defs = Data.index_by(Data.load_json("seals.json"), "id")
	ability_defs = Data.load_json("abilities.json")


func add_evidence(id: String) -> bool:
	if evidence.has(id):
		return false
	evidence[id] = true
	return true


func pin(id: String, question: String) -> bool:
	if not evidence.has(id) or not question in ["who", "what", "when", "why"]:
		return false
	pins[id] = question
	return true


func link(a: String, b: String) -> bool:
	if not (pins.has(a) and pins.has(b)) or a == b:
		return false
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return false
	links.append([a, b])
	return true


func set_tool(tool_id: String, available: bool) -> void:
	tools_available[tool_id] = available


## Why a seal cannot be tested now, or "" if it can.
func block_reason(seal_id: String) -> String:
	if not seal_defs.has(seal_id):
		return "unknown"
	if seals.has(seal_id):
		return "already_sealed"
	var d: Dictionary = seal_defs[seal_id]
	if not tools_available.get(d["tool"], false):
		return "needs_tool:%s" % d["tool"]
	for e in d["evidence"]:
		if not pins.has(e):
			return "needs_pinned:%s" % e
	return ""


func can_test(seal_id: String) -> bool:
	return block_reason(seal_id) == ""


## Call when the player passes the seal's test. Returns true if newly sealed.
func complete_test(seal_id: String, day: int) -> bool:
	if not can_test(seal_id):
		return false
	seals[seal_id] = day
	return true


## Are all of these pinned cards joined (directly or through others) by strings?
func links_connect(ids: Array) -> bool:
	if ids.size() <= 1:
		return true
	var seen := {ids[0]: true}
	var frontier: Array = [ids[0]]
	while not frontier.is_empty():
		var cur: String = frontier.pop_back()
		for l in links:
			var other := ""
			if l[0] == cur:
				other = l[1]
			elif l[1] == cur:
				other = l[0]
			if other != "" and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	for i in ids:
		if not seen.has(i):
			return false
	return true


## The generic Seal test: right tool, evidence pinned, and the strings join it up.
func try_link_test(seal_id: String, day: int) -> bool:
	if not can_test(seal_id):
		return false
	if not links_connect(seal_defs[seal_id]["evidence"]):
		return false
	return complete_test(seal_id, day)


## Seals the player could test right now (tool available, evidence pinned, unsealed).
func testable() -> Array:
	var out: Array = []
	for id in seal_defs:
		if seal_defs[id]["evidence"].size() > 0 and can_test(id):
			out.append(id)
	out.sort()
	return out


func count_layer(layer: String) -> int:
	var n := 0
	for id in seals:
		if seal_defs[id]["layer"] == layer:
			n += 1
	return n


func layer_total(layer: String) -> int:
	var n := 0
	for id in seal_defs:
		if seal_defs[id]["layer"] == layer:
			n += 1
	return n


func abilities() -> Array:
	var out: Array = []
	for a in ability_defs:
		var need: int = layer_total(a["layer"]) if a["id"] == "fair_water" else int(a["count"])
		if count_layer(a["layer"]) >= need:
			out.append(a["id"])
	return out


func has_ability(id: String) -> bool:
	return abilities().has(id)


func to_dict() -> Dictionary:
	return {"evidence": evidence.keys(), "pins": pins, "links": links, "seals": seals}


func load_dict(d: Dictionary) -> void:
	evidence.clear()
	for e in d.get("evidence", []):
		evidence[e] = true
	pins = d.get("pins", {}).duplicate()
	links = d.get("links", []).duplicate(true)
	seals = {}
	for k in d.get("seals", {}):
		seals[k] = int(d["seals"][k])
