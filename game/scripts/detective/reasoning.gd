extends RefCounted
## Rules of evidence (R3). Proof is computed here, and only here, from the CONTENT of the claims in the notebook: placing a person at the
## scene near the time of death is opportunity; a purchase or a weapon in their home is means; a quarrel is motive; an item or trace that
## is theirs is a link; a verified elsewhere-claim exonerates. How sure the source sounded (certainty) discounts the weight. Nothing here
## ever sees the truth: a claim that is secretly false weighs exactly as much as a true one until the court (Justice) finds out.
## The same rules feed the DA's qualitative advice, so the player gets a read of the case without a number that leaks the answer.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")

const CATS := ["opportunity", "means", "motive", "link", "exonerate"]
const CASE_CATS := ["opportunity", "means", "motive", "link"]

## predicate -> [[category, base strength], ...] at full certainty.
const RULES := {
	"holds_key": [["opportunity", 1]],
	"seen_at_scene": [["opportunity", 3]],
	"seen_out_at_night": [["opportunity", 3]],
	"seen_going_out": [["opportunity", 3]],
	"seen_near_victim": [["opportunity", 1]],
	"carried_bundle": [["opportunity", 1]],
	"call_from_home": [["opportunity", 2]],
	"last_seen_with_victim": [["opportunity", 1]],
	"confessed": [["opportunity", 3]],
	"confessed_story": [["opportunity", 3], ["means", 1], ["motive", 1]],
	"weapon_in_home": [["means", 3]],
	"weapon_on_grounds": [["means", 1]],
	"bought_weapon": [["means", 2]],
	"owns_matching_set": [["means", 2]],
	"motive_quarrel": [["motive", 2]],
	"motive_document": [["motive", 1]],
	"motive_confided": [["motive", 2]],
	"motive_bad_blood": [["motive", 1]],
	"motive_open_hostility": [["motive", 2]],
	"motive_vendetta": [["motive", 3]],
	"item_recognised": [["link", 2]],
	"footwear_matches": [["link", 3]],
	"coat_traces": [["link", 2]],
	"print_match": [["link", 3]],
	"item_resembles": [["link", 2]],
	"knew_unreleased": [["link", 2]],
	"washed_evidence": [["link", 2]],
	"elsewhere": [["exonerate", 3]],
	"left_before_death": [["exonerate", 1]],
	"witness_discredited": [["exonerate", 2]],
	"item_planted": [["exonerate", 2]],
	"confession_disproved": [["exonerate", 3]],
}
const TIME_CHECKED := ["seen_at_scene", "seen_out_at_night", "seen_going_out", "call_from_home"]
const DEFAULT_WINDOW := [21.0, 31.0]
const TOLERANCE := 0.75


static func entries_of(notebook: Variant) -> Array:
	if notebook is Dictionary:
		return (notebook as Dictionary).values()
	return notebook


static func _strength(base: int, certainty: float) -> int:
	if certainty < 0.3:
		return 0
	return maxi(1, int(round(float(base) * certainty)))


## The window the notebook gives for the time of death, with some give either side (clocks are never exact).
static func death_window(notebook: Variant) -> Array:
	for e in entries_of(notebook):
		for cl in e.get("claims", []):
			if cl.get("predicate", "") == "time_of_death" and float(cl.get("time", -1.0)) >= 0.0:
				return [float(cl["time"]) - TOLERANCE, float(cl.get("until", cl["time"])) + TOLERANCE]
	return DEFAULT_WINDOW


static func _overlaps(cl: Dictionary, win: Array) -> bool:
	var t: float = float(cl.get("time", -1.0))
	if t < 0.0:
		return true
	var u: float = float(cl.get("until", -1.0))
	if u < 0.0:
		u = t
	return t <= float(win[1]) and u >= float(win[0])


## What the notebook says about one person, by category: {opportunity, means, motive, link, exonerate} -> strength.
## `case_file` is the public case file; `jobs` maps resident id -> job (public knowledge: it is how a trace is tied to a trade).
static func proof_against(notebook: Variant, case_file: Dictionary, person: String, jobs: Dictionary = {}) -> Dictionary:
	var out := {"opportunity": 0, "means": 0, "motive": 0, "link": 0, "exonerate": 0}
	var entries: Array = entries_of(notebook)
	var win: Array = death_window(entries)
	var scene: String = String(case_file.get("scene", ""))
	var weapon_sites := {}
	var known_for := {}
	var odd_details := {}
	for e in entries:
		for cl in e.get("claims", []):
			match String(cl.get("predicate", "")):
				"weapon_on_grounds":
					weapon_sites[String(cl.get("place", ""))] = true
				"known_for":
					if cl.get("subject", "") == person:
						known_for[String(cl.get("item", ""))] = true
				"odd_detail":
					odd_details[String(cl.get("item", ""))] = true
	var job: String = String(jobs.get(person, ""))
	for e in entries:
		for cl in e.get("claims", []):
			var pred: String = String(cl.get("predicate", ""))
			var cert: float = float(cl.get("certainty", 1.0))
			var subj: String = String(cl.get("subject", ""))
			if subj == "":
				if pred == "figure_seen" and known_for.has(String(cl.get("item", ""))) and _overlaps(cl, win):
					out["opportunity"] = int(out["opportunity"]) + _strength(1, cert)
				elif pred == "trace_occupation" and job != "":
					var tr: String = CaseEngine.trace_for(job)
					if tr == String(cl.get("item", "")):
						out["link"] = int(out["link"]) + _strength(1 if tr == "grey cotton lint" else 2, cert)
				continue
			if subj != person:
				continue
			if pred.begins_with("legacy_"):
				var lc: String = pred.substr(7)
				if out.has(lc):
					out[lc] = int(out[lc]) + int(cl.get("item", "0"))
				continue
			if pred == "print_match" and (person == String(case_file.get("found_by", "")) or person == String(case_file.get("victim", ""))):
				continue        # their prints belong at that scene: proving they were there proves nothing
			if pred == "seen_at_scene" and scene != "" and String(cl.get("place", "")) not in ["", scene]:
				continue
			if pred in TIME_CHECKED and not _overlaps(cl, win):
				continue
			if pred == "elsewhere" and not _overlaps(cl, win):
				continue
			if pred == "left_before_death" and float(cl.get("time", -1.0)) >= float(win[0]) + TOLERANCE:
				continue
			if pred == "carried_bundle" and weapon_sites.has(String(cl.get("place", ""))):
				out["means"] = int(out["means"]) + _strength(1, cert)
			if pred == "confessed" and String(cl.get("item", "")) != "" and odd_details.has(String(cl.get("item", ""))):
				# a confession that holds the one detail nobody was told
				out["motive"] = int(out["motive"]) + _strength(2, cert)
				out["means"] = int(out["means"]) + _strength(2, cert)
			for rule in RULES.get(pred, []):
				out[rule[0]] = int(out[rule[0]]) + _strength(int(rule[1]), cert)
	return out


## The cases-in-brief of a proof: how many kinds of proof, and how much in all.
static func tally(pr: Dictionary) -> Dictionary:
	var cats := 0
	var total := 0
	for k in CASE_CATS:
		if int(pr[k]) > 0:
			cats += 1
		total += int(pr[k])
	return {"cats": cats, "total": total}


## Everyone named by a claim in the notebook, in the order they first appear.
static func people_named(notebook: Variant) -> Array:
	var out: Array = []
	for e in entries_of(notebook):
		for cl in e.get("claims", []):
			var s: String = String(cl.get("subject", ""))
			if s != "" and not out.has(s):
				out.append(s)
	return out


## The motive the notebook's documents and witnesses point to for one person ("" when nothing names a kind).
static func motive_guess(notebook: Variant, person: String) -> String:
	var votes := {}
	for e in entries_of(notebook):
		for cl in e.get("claims", []):
			if cl.get("subject", "") == person and String(cl.get("predicate", "")).begins_with("motive_") and String(cl.get("item", "")) != "":
				votes[cl["item"]] = int(votes.get(cl["item"], 0)) + 1
	var best := ""
	var bn := 0
	for k in votes:
		if int(votes[k]) > bn:
			bn = int(votes[k])
			best = String(k)
	return best


## The cause of death the scene gave the detective ("" if the body has not been read).
static func method_guess(notebook: Variant) -> String:
	for e in entries_of(notebook):
		for cl in e.get("claims", []):
			if cl.get("predicate", "") == "cause_of_death":
				return String(cl.get("item", ""))
	return ""


## Why a claim may not hold, in the words of someone who read the notebook (never because the truth is known).
static func doubt_of(cl: Dictionary) -> String:
	var cert: float = float(cl.get("certainty", 1.0))
	if cert >= 0.8:
		return ""
	match String(cl.get("kind", "")):
		"seen", "heard":
			return "your witness saw it in poor light and could not swear to it" if cert < 0.55 else "your witness hedged on the hour"
		"said":
			return "that is only what someone says they were told"
		"recorded":
			return "the footage is poor and its clock was never checked" if cert < 0.65 else "the footage is not as sharp as it could be"
		"found":
			return "the sample or print was only partial" if cert < 0.65 else "that one is not as clear as it could be"
	return "that one is not certain"


## The DA's read of a case against one person: qualitative, from the notebook alone. Never a number, never the truth.
static func da_read(notebook: Variant, case_file: Dictionary, person: String, jobs: Dictionary = {}, person_name: String = "") -> String:
	var nm: String = person_name if person_name != "" else "this person"
	var pr: Dictionary = proof_against(notebook, case_file, person, jobs)
	var t: Dictionary = tally(pr)
	var win: Array = death_window(notebook)
	var lines: Array = []
	var weak := {}
	for e in entries_of(notebook):
		for cl in e.get("claims", []):
			if cl.get("subject", "") != person:
				continue
			var d: String = doubt_of(cl)
			var pred: String = String(cl.get("predicate", ""))
			if d == "" or not RULES.has(pred):
				continue
			for rule in RULES[pred]:
				if rule[0] in CASE_CATS and not weak.has(rule[0]):
					weak[rule[0]] = d
	var say := func(cat: String, yes: String, no: String) -> void:
		if int(pr[cat]) > 0:
			lines.append(yes + (", but %s" % weak[cat] if weak.has(cat) else ""))
		else:
			lines.append(no)
	say.call("opportunity", "This puts %s out and about at the time" % nm, "Nothing yet puts %s near it at the time" % nm)
	say.call("means", "You can show how %s could have done it" % nm, "You cannot show how %s got hold of the means" % nm)
	say.call("motive", "There is a reason someone would have wanted this" , "You have no reason on file")
	say.call("link", "Something physical ties %s to the scene" % nm, "Nothing physical ties %s to the scene" % nm)
	if int(pr["exonerate"]) >= 3:
		lines.append("The defence will say your own notebook clears %s" % nm)
	elif int(pr["exonerate"]) > 0:
		lines.append("Someone has spoken for %s, and the defence will use it" % nm)
	var verdict := ""
	if int(t["cats"]) >= 3 and int(t["total"]) >= 6 and int(pr["exonerate"]) < 3:
		verdict = "This is the shape of a case. Whether it survives a defence depends on how many of those witnesses and records hold."
	elif int(t["cats"]) >= 2:
		verdict = "Enough to charge, thin to try. A jury needs more than that."
	else:
		verdict = "Not a case. The Sheriff will not let you arrest on this."
	if int(pr["opportunity"]) == 0 and int(pr["link"]) == 0:
		verdict += " Get something that puts them there."
	return ". ".join(lines) + ".\n\n" + verdict
