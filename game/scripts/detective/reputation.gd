extends RefCounted
## The one reputation ledger. Every outcome in the game (a conviction, a wrong accusation, a hung jury, a cold file, a caught killer,
## a funeral attended) goes through `apply`, so the same thing always costs or earns the same, and every change is written down.
## Three standings: the Sheriff (how much they trust your work), the town (how much they like and fear you), and the chapel
## (whether the old parts of the town will tell you what they know).

const TABLE := {
	"convicted_killer": {"sheriff": 10, "town": 5, "chapel": 0},
	"wrongful_conviction": {"sheriff": -6, "town": -8, "chapel": -2},
	"wrong_accusation": {"sheriff": -8, "town": -6, "chapel": -1},
	"hung_jury": {"sheriff": -2, "town": -1, "chapel": 0},
	"acquitted_guilty": {"sheriff": -5, "town": -2, "chapel": 0},
	"released_right": {"sheriff": -2, "town": 0, "chapel": 0},
	"insufficient": {"sheriff": -2, "town": 0, "chapel": 0},
	"failed_arrest": {"sheriff": -5, "town": -3, "chapel": 0},
	"appeal_win": {"sheriff": -2, "town": 6, "chapel": 2},
	"serial_caught_big": {"sheriff": 25, "town": 20, "chapel": 4},
	"serial_caught": {"sheriff": 10, "town": 8, "chapel": 1},
	"serial_failed": {"sheriff": -30, "town": -10, "chapel": -2},
	"serial_pressure_light": {"sheriff": 0, "town": -1, "chapel": 0},
	"serial_pressure": {"sheriff": 0, "town": -2, "chapel": 0},
	"serial_pressure_sheriff": {"sheriff": -2, "town": 0, "chapel": 0},
	"serial_pressure_siege": {"sheriff": -4, "town": 0, "chapel": 0},
	"accusations_spent": {"sheriff": -20, "town": -8, "chapel": -2},
	"cold_drain": {"sheriff": -1, "town": 0, "chapel": 0},
	"cold_drain_town": {"sheriff": 0, "town": -1, "chapel": 0},
	"cold_case": {"sheriff": -10, "town": -5, "chapel": -1},
	"occult_solved": {"sheriff": 0, "town": 1, "chapel": 4},
	"occult_exposed": {"sheriff": 0, "town": 0, "chapel": -3},
	"funeral": {"sheriff": 0, "town": 1, "chapel": 3},
	"sermon": {"sheriff": 0, "town": 0, "chapel": 1},
	"business_solved": {"sheriff": 1, "town": 2, "chapel": 0},
	"business_failed": {"sheriff": 0, "town": -1, "chapel": 0},
	"false_confession_jailed": {"sheriff": -3, "town": -6, "chapel": -1}
}

const LIMIT := 100


## Apply an event to the detective's standing. `scale` multiplies it (escalating costs); returns the deltas actually applied.
static func apply(det: RefCounted, event: String, day: int = 0, scale: float = 1.0) -> Dictionary:
	var row: Dictionary = TABLE.get(event, {})
	var out := {}
	for k in ["sheriff", "town", "chapel"]:
		var d := int(round(float(row.get(k, 0)) * scale))
		if d != 0:
			det.reputation[k] = clampi(int(det.reputation.get(k, 0)) + d, -LIMIT, LIMIT)
		out[k] = d
	if not det.get("rep_log") is Array:
		return out
	det.rep_log.append({"day": day, "event": event, "d": out})
	if det.rep_log.size() > 60:
		det.rep_log.pop_front()
	return out


## How much a wrong accusation costs, rising with each one in the same case: the third is a disaster.
static func escalation(n_wrong: int) -> float:
	return 1.0 + 0.75 * float(maxi(n_wrong - 1, 0))


static func chapel_tier(det: RefCounted) -> String:
	var c: int = int(det.reputation.get("chapel", 0))
	if c >= 8:
		return "trusted"
	if c >= 4:
		return "welcome"
	if c <= -6:
		return "shunned"
	if c <= -2:
		return "wary"
	return "neutral"


## Does the chapel let you in on old-town business (the vigil, the choir, the hymn that isn't in the book)?
static func chapel_opens(det: RefCounted) -> bool:
	return chapel_tier(det) in ["neutral", "welcome", "trusted"]


static func describe(det: RefCounted) -> String:
	var s: int = int(det.reputation.get("sheriff", 0))
	var t: int = int(det.reputation.get("town", 0))
	return "Sheriff %+d, town %+d, chapel %+d (%s)" % [s, t, int(det.reputation.get("chapel", 0)), chapel_tier(det)]
