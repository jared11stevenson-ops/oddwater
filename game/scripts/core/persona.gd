extends RefCounted
## The player's own character: created once, consistent in every body. Their voice does not change when
## their body does. Only the lines they choose to say IN COVER sound like someone else.

const Data = preload("res://scripts/core/data.gd")

var name := "Alex"
var pronoun_id := "they"
var archetype := "dry"
var catchphrase := ""
var cfg: Dictionary


func _init() -> void:
	cfg = Data.load_json("persona.json")
	catchphrase = cfg["catchphrases"][0]


static func make(p_name: String, p_pronoun: String, p_archetype: String, p_catch: String) -> RefCounted:
	var p: RefCounted = load("res://scripts/core/persona.gd").new()
	p.name = p_name.strip_edges() if p_name.strip_edges() != "" else "Alex"
	p.pronoun_id = p_pronoun if p_pronoun in ["they", "she", "he"] else "they"
	p.archetype = p_archetype if cfg_has(p, p_archetype) else "dry"
	p.catchphrase = p_catch if p_catch != "" else p.cfg["catchphrases"][0]
	return p


static func cfg_has(p: RefCounted, a: String) -> bool:
	return p.cfg["archetypes"].has(a)


func pronouns() -> Dictionary:
	for pr in cfg["pronouns"]:
		if pr["id"] == pronoun_id:
			return pr
	return cfg["pronouns"][0]


## 0 = same voice, 1 = nothing alike. Symmetric.
func distance_to(style: String) -> float:
	if style == "self" or style == archetype:
		return 0.0
	var k := "%s|%s" % [archetype, style]
	var k2 := "%s|%s" % [style, archetype]
	if cfg["distance"].has(k):
		return float(cfg["distance"][k])
	return float(cfg["distance"].get(k2, 0.5))


## How much speaking as yourself, in this host's company, risks a raised eyebrow (0..~12).
func self_risk(host_style: String) -> int:
	if host_style == "self":
		return 0
	return int(round(float(cfg["self_suspicion_base"]) + distance_to(host_style) * float(cfg["self_suspicion_per_distance"])))


## Put the player's own voice on a line they say AS THEMSELVES. Deterministic. Stage directions are left alone.
func voice(text: String) -> String:
	if not text.begins_with("\""):
		return text
	var prefixes: Array = cfg["archetypes"][archetype]["prefix"]
	var h := absi(hash(name + text))
	var out: String = "\"" + String(prefixes[h % prefixes.size()]) + text.substr(1)
	if h % 4 == 0 and out.ends_with("\""):
		out = out.substr(0, out.length() - 1) + " " + catchphrase + "\""
	return out


## Narration about the player, in their own head. Always the same person.
func inner(line: String) -> String:
	return line.replace("{you}", name).replace("{subj}", pronouns()["subj"]).replace("{obj}", pronouns()["obj"]).replace("{poss}", pronouns()["poss"])


func to_dict() -> Dictionary:
	return {"name": name, "pronoun": pronoun_id, "archetype": archetype, "catch": catchphrase}


static func from_dict(d: Dictionary) -> RefCounted:
	return make(d.get("name", "Alex"), d.get("pronoun", "they"), d.get("archetype", "dry"), d.get("catch", ""))
