extends RefCounted
## Claims: the one doorway between what happened (the truth) and what the detective is told or sees (the notebook).
## A claim is {kind: seen|heard|found|recorded|said, subject, predicate, place, time, until, item, certainty, source, text}.
## The generator and the perception filters write claim TEMPLATES (they may carry a private "_truth_tag": true | false | misleading).
## `emit` is the only place a template becomes notebook data: it strips everything private, gives the claim an opaque id, and files the
## tag in the truth's own id map (`claim_tags`). The notebook never holds a tag; the adjudicator (court) looks it up by the opaque id.

const KINDS := ["seen", "heard", "found", "recorded", "said"]


## A claim template. `time`/`until` are hours (24+ is after midnight), -1 when unknown. `certainty` is how sure the source sounds (0-1).
static func make(kind: String, subject: String, predicate: String, place: String = "", time: float = -1.0, item: String = "", certainty: float = 1.0, tag: String = "true", until: float = -1.0) -> Dictionary:
	return {"kind": kind, "subject": subject, "predicate": predicate, "place": place, "time": time, "until": until, "item": item, "certainty": certainty, "_truth_tag": tag}


## Turn templates into notebook claims for an entry: opaque ids, source and display text, nothing private. The tags go into the truth's map.
static func emit(truth: Dictionary, templates: Array, source: String, text: String) -> Array:
	if not truth.has("claim_tags"):
		truth["claim_tags"] = {}
	var out: Array = []
	for t in templates:
		var cl: Dictionary = {}
		for k in (t as Dictionary):
			if not String(k).begins_with("_"):
				cl[k] = t[k]
		var n: int = int(truth.get("claim_seq", 0)) + 1
		truth["claim_seq"] = n
		cl["cid"] = "k%d" % n
		cl["source"] = source
		cl["text"] = text
		(truth["claim_tags"] as Dictionary)[cl["cid"]] = String(t.get("_truth_tag", "true"))
		out.append(cl)
	return out


## What the court knows about a claim that the detective does not: true, false (a lie or a mistake) or misleading (true as far as it goes).
static func tag_of(truth: Dictionary, claim: Dictionary) -> String:
	return String((truth.get("claim_tags", {}) as Dictionary).get(String(claim.get("cid", "")), "true"))


## Re-tag a claim already in the notebook (a lab result that settles a doubt, a confession that fails the test).
static func retag(truth: Dictionary, claim: Dictionary, tag: String) -> void:
	if not truth.has("claim_tags"):
		truth["claim_tags"] = {}
	(truth["claim_tags"] as Dictionary)[String(claim.get("cid", ""))] = tag


## The claims of a notebook entry (always an array; old saved entries have none).
static func of(entry: Dictionary) -> Array:
	return entry.get("claims", [])
