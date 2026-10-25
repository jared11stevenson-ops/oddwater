extends RefCounted
## Scarce resources. The clock already limits a day; these limit a case. Warrants (a judge signs few), lab slots (per day), evidence-kit
## uses (every surface dusted, every set of prints rolled, every frame photographed), favours (what the town will do for you once) and
## hunches (a lead from your own gut). They are kept on the detective (`det.res`), refilled when a case opens, and replenish slowly with
## the days and with level and rank. Budgets are set so the claims-only bot, which prioritises, still solves every seed with margin.

const BASE := {"warrants": 2, "kit": 20, "favours": 3, "hunches": 2}
const LABELS := {"warrants": "Warrants", "kit": "Kit", "favours": "Favours", "hunches": "Hunches", "lab": "Lab"}
const LEVEL_SEEN := "level_seen"


static func caps(det: RefCounted) -> Dictionary:
	var lv: int = int(det.level)
	var deputy: bool = String(det.rank) == "Deputy"
	var w: int = 2 + (1 if lv >= 4 else 0) + (1 if lv >= 8 else 0) - (1 if deputy else 0)
	var k: int = 20 + mini(lv - 1, 6) - (4 if deputy else 0)
	var f: int = 4 + (1 if int(det.reputation.get("sheriff", 0)) >= 30 else 0)
	var h: int = 2 + lv / 3
	return {"warrants": maxi(w, 1), "kit": k, "favours": f, "hunches": h}


static func lab_slots(det: RefCounted) -> int:
	return 3 + (1 if int(det.level) >= 5 else 0) - (1 if String(det.rank) == "Deputy" else 0)


static func ensure(det: RefCounted) -> void:
	if det.res.is_empty():
		det.res = {"warrants": BASE["warrants"], "kit": BASE["kit"], "favours": BASE["favours"], "hunches": BASE["hunches"],
			"lab_day": -1, "lab_used": 0, "dusted": {}, LEVEL_SEEN: int(det.level), "day": 0}
	var seen: int = int(det.res.get(LEVEL_SEEN, det.level))
	if int(det.level) > seen:
		det.res["hunches"] = mini(int(det.res["hunches"]) + (int(det.level) - seen), int(caps(det)["hunches"]))
		det.res[LEVEL_SEEN] = int(det.level)


static func get_n(det: RefCounted, key: String) -> int:
	ensure(det)
	return int(det.res.get(key, 0))


static func has(det: RefCounted, key: String, n: int = 1) -> bool:
	return get_n(det, key) >= n


static func spend(det: RefCounted, key: String, n: int = 1) -> bool:
	if not has(det, key, n):
		return false
	det.res[key] = int(det.res[key]) - n
	return true


static func gain(det: RefCounted, key: String, n: int = 1) -> void:
	ensure(det)
	det.res[key] = mini(int(det.res.get(key, 0)) + n, int(caps(det).get(key, 99)))


## A new file opens: warrants, kit and hunches refill to what your rank allows; favours carry over (they are relationships, not paperwork).
static func new_case(det: RefCounted, day: int) -> void:
	ensure(det)
	var c: Dictionary = caps(det)
	det.res["warrants"] = c["warrants"]
	det.res["kit"] = c["kit"]
	det.res["hunches"] = c["hunches"]
	det.res["favours"] = mini(int(det.res["favours"]) + 1, int(c["favours"]))
	det.res["lab_used"] = 0
	det.res["lab_day"] = day
	det.res["dusted"] = {}
	det.res["day"] = day


## Each dawn: the kit is restocked a little, the judge's patience returns every fourth day, a favour comes round every third.
static func dawn(det: RefCounted, day: int) -> void:
	ensure(det)
	if int(det.res.get("day", 0)) >= day:
		return
	det.res["day"] = day
	gain(det, "kit", 1)
	if day % 4 == 0:
		gain(det, "warrants", 1)
	if day % 3 == 0:
		gain(det, "favours", 1)


static func lab_used(det: RefCounted, day: int) -> int:
	ensure(det)
	return int(det.res["lab_used"]) if int(det.res["lab_day"]) == day else 0


static func lab_free(det: RefCounted, day: int) -> int:
	return maxi(lab_slots(det) - lab_used(det, day), 0)


static func use_lab(det: RefCounted, day: int) -> void:
	ensure(det)
	if int(det.res["lab_day"]) != day:
		det.res["lab_day"] = day
		det.res["lab_used"] = 0
	det.res["lab_used"] = int(det.res["lab_used"]) + 1


## One line for the HUD: what is left.
static func summary(det: RefCounted, day: int) -> String:
	var c: Dictionary = caps(det)
	return "Warrants %d/%d  Lab %d/%d  Kit %d/%d  Favours %d  Hunches %d" % [get_n(det, "warrants"), int(c["warrants"]), lab_free(det, day), lab_slots(det),
		get_n(det, "kit"), int(c["kit"]), get_n(det, "favours"), get_n(det, "hunches")]


## For the screens: [{key, label, have, cap, note}].
static func rows(det: RefCounted, day: int) -> Array:
	var c: Dictionary = caps(det)
	return [
		{"key": "warrants", "label": "Warrants", "have": get_n(det, "warrants"), "cap": int(c["warrants"]), "note": "a judge signs few; one more every fourth day"},
		{"key": "lab", "label": "Lab slots today", "have": lab_free(det, day), "cap": lab_slots(det), "note": "fresh each morning"},
		{"key": "kit", "label": "Evidence kit", "have": get_n(det, "kit"), "cap": int(c["kit"]), "note": "dust, prints, photographs; restocked a little each day"},
		{"key": "favours", "label": "Favours", "have": get_n(det, "favours"), "cap": int(c["favours"]), "note": "informants, deals, a late night at the lab"},
		{"key": "hunches", "label": "Hunches", "have": get_n(det, "hunches"), "cap": int(c["hunches"]), "note": "refill with each new file and with level"}]
