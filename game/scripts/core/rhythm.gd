extends RefCounted
## Two-lane drum rhythm (KICK = 0, SNARE = 1). Cozy by design: a miss costs combo, never the run.
## Time-based and deterministic, so it is unit-testable; the UI only feeds in tap times.

const Data = preload("res://scripts/core/data.gd")

var song: Dictionary
var notes: Array = []        # {t, lane, state}  state: "pending" | "perfect" | "good" | "miss"
var leniency := 1.0          # accessibility: >1 widens the windows
var combo := 0
var best_combo := 0
var perfect_w := 0.07
var good_w := 0.14


func _init(song_id: String, lenient: float = 1.0) -> void:
	song = Data.load_json("rhythm/songs.json")[song_id]
	leniency = lenient
	var spb := 60.0 / float(song["bpm"])
	for n in song["notes"]:
		notes.append({"t": float(song["lead_in"]) + float(n[0]) * spb, "lane": int(n[1]), "state": "pending"})
	notes.sort_custom(func(a, b): return a["t"] < b["t"])


func duration() -> float:
	return notes[-1]["t"] + 1.5


## Feed a tap. Returns "perfect", "good" or "miss" (a stray tap does not break combo twice).
func tap(lane: int, now: float) -> String:
	var best := -1
	var best_d := INF
	for i in notes.size():
		var n: Dictionary = notes[i]
		if n["state"] != "pending" or n["lane"] != lane:
			continue
		var d := absf(n["t"] - now)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0 and best_d <= good_w * leniency:
		var res := "perfect" if best_d <= perfect_w * leniency else "good"
		notes[best]["state"] = res
		combo += 1
		best_combo = maxi(best_combo, combo)
		return res
	combo = 0
	return "miss"


## Mark notes the player let go by.
func update(now: float) -> void:
	for n in notes:
		if n["state"] == "pending" and now > n["t"] + good_w * leniency:
			n["state"] = "miss"
			combo = 0


func counts() -> Dictionary:
	var c := {"perfect": 0, "good": 0, "miss": 0, "pending": 0}
	for n in notes:
		c[n["state"]] += 1
	return c


func accuracy() -> float:
	var c := counts()
	var total: int = notes.size()
	return (float(c["perfect"]) + 0.8 * float(c["good"])) / float(total)


func stars() -> int:
	var a := accuracy()
	return 3 if a >= 0.9 else (2 if a >= 0.7 else (1 if a >= 0.4 else 0))


## The Reply: the lake answers if you play the long roll steadily enough.
func reply_answered() -> bool:
	return accuracy() >= float(song.get("answer_at", 0.75))
