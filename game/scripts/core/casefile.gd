extends RefCounted
## The case file: the Pattern grid and the proof of the Rule.
## The player collects facts about each host (was the host on the edge the night before? did they carry the mark of a big
## decision? was there a ribbon?), reads the grid, and then PREDICTS tomorrow's host. Two correct predictions prove the Rule,
## and a proven Rule turns the Long Night into a forecast the player can steer.

const HITS_TO_PROVE := 2

var log: Array = []             # one row per host the Cause has taken: {day, id, edge, trace, ribbon}
var predictions: Array = []     # {day, guess, actual, hit}
var guess_for_tonight := ""
var edge_ids: Array = []        # who looked on the edge at the start of tonight's Long Night
var traces: Dictionary = {}     # life id -> true once the player has found that life's decision in their home
var ribbons: Dictionary = {}    # life id -> true once the player saw the ribbon go up
var rule_proven := false


## Called when the Long Night opens: remember who looked on the edge tonight.
func open_night(edge_report: Array) -> void:
	edge_ids = edge_report.map(func(e): return e["id"])
	guess_for_tonight = ""


func found_trace(life_id: String) -> void:
	traces[life_id] = true


func saw_ribbon(life_id: String) -> void:
	ribbons[life_id] = true


## One guess per night. Can be changed until sleep.
func predict(id: String) -> void:
	guess_for_tonight = id


## At 4:12 the Cause picks. Log the host, and score the guess.
func resolve(day: int, actual: String) -> Dictionary:
	log.append({"day": day, "id": actual, "edge": edge_ids.has(actual)})
	var res := {"had_guess": guess_for_tonight != "", "hit": false, "proved_now": false}
	if guess_for_tonight != "":
		var hit := guess_for_tonight == actual
		# a hit only PROVES the Rule if the person was visibly on the edge: a lucky guess at a calm person proves nothing
		var earned := hit and edge_ids.has(actual)
		predictions.append({"day": day, "guess": guess_for_tonight, "actual": actual, "hit": hit, "earned": earned})
		res["hit"] = hit
		res["earned"] = earned
		if earned and not rule_proven and hits() >= HITS_TO_PROVE:
			rule_proven = true
			res["proved_now"] = true
	guess_for_tonight = ""
	return res


## Correct predictions that count toward the proof.
func hits() -> int:
	var n := 0
	for p in predictions:
		if p.get("earned", false):
			n += 1
	return n


## The grid as rows of strings. `name_of` maps a life id to a display name.
func rows(name_of: Callable) -> Array:
	var out: Array = []
	for r in log:
		out.append({"day": r["day"], "who": name_of.call(r["id"]),
			"edge": "on the edge" if r["edge"] else "seemed fine",
			"trace": "a big decision, found" if traces.has(r["id"]) else "not looked for",
			"ribbon": "ribbon seen" if ribbons.has(r["id"]) else "-"})
	return out


func grid_text(name_of: Callable) -> String:
	if log.is_empty():
		return "Nobody has been taken since you started keeping this. Watch who goes."
	var s := "DAY  HOST                 THE NIGHT BEFORE   THEIR HOME                RIBBON\n"
	for r in rows(name_of):
		s += "%-4d %-20s %-18s %-25s %s\n" % [r["day"], r["who"], r["edge"], r["trace"], r["ribbon"]]
	s += "\nPredictions: %d right of %d. " % [hits(), predictions.size()]
	s += "THE RULE IS PROVEN." if rule_proven else "Get %d right to prove the Rule." % maxi(0, HITS_TO_PROVE - hits())
	return s


## Once the Rule is proven, the Long Night shows the Cause's order: a forecast to steer against.
func forecast(cause: RefCounted, sim: RefCounted, eligible: Array, name_of: Callable) -> Array:
	if not rule_proven:
		return []
	var out: Array = []
	for r in cause.ranking(sim, eligible).slice(0, 3):
		out.append(name_of.call(r["id"]))
	return out


func to_dict() -> Dictionary:
	return {"log": log.duplicate(true), "predictions": predictions.duplicate(true), "traces": traces.duplicate(), "ribbons": ribbons.duplicate(), "proven": rule_proven}


static func from_dict(d: Dictionary) -> RefCounted:
	var c: RefCounted = load("res://scripts/core/casefile.gd").new()
	c.log = d.get("log", []).duplicate(true)
	c.predictions = d.get("predictions", []).duplicate(true)
	c.traces = d.get("traces", {}).duplicate()
	c.ribbons = d.get("ribbons", {}).duplicate()
	c.rule_proven = bool(d.get("proven", false))
	return c
