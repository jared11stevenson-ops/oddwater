extends RefCounted
## What two people are to each other, in words. Stage comes from affinity and trust; family is named by the household.

static func stage(affinity: float, trust: float) -> String:
	if affinity >= 75.0 and trust >= 60.0:
		return "best friend"
	if affinity >= 50.0 and trust >= 35.0:
		return "close friend"
	if affinity >= 25.0:
		return "friend"
	if affinity >= 8.0:
		return "acquaintance"
	if affinity <= -50.0:
		return "enemy"
	if affinity <= -20.0:
		return "rival"
	if affinity < -5.0:
		return "on bad terms"
	return "stranger"


## How `other` is related to `me`: family if they share a home, otherwise the stage.
static func describe(sim: RefCounted, me: String, other: String) -> String:
	var a: RefCounted = sim.people[me]
	var b: RefCounted = sim.people[other]
	if a.home == b.home and a.home != "":
		var brief := load("res://scripts/sim/brief.gd")
		return String(brief._role(b, a))
	return stage(b.affinity(me), b.trust(me))
