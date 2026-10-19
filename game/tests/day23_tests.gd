extends SceneTree
## godot --headless --path game -s tests/day23_tests.gd : content integrity + Honesty Pull + eavesdrop.

const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
const Eavesdrop = preload("res://scripts/core/eavesdrop.gd")
const Data = preload("res://scripts/core/data.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var ev: Dictionary = Data.load_json("evidence.json")
	# every convo is well-formed, every evidence id used anywhere has a card
	for f in ["day01.json", "day02.json", "day03.json", "day04.json", "day05.json"]:
		var all: Dictionary = Data.load_json("convos/" + f)
		for id in all:
			var nodes: Dictionary = all[id]["nodes"]
			ok(nodes.has(all[id]["start"]), "%s/%s start" % [f, id])
			if all[id].has("blurt"):
				ok(nodes.has(all[id]["blurt"]), "%s/%s blurt exists" % [f, id])
			var ends := false
			for nid in nodes:
				var n: Dictionary = nodes[nid]
				if n.get("end", false): ends = true
				if n.has("evidence"): ok(ev.has(n["evidence"]), "%s/%s/%s evidence card %s" % [f, id, nid, n["evidence"]])
				ok(n.get("end", false) or n.get("choices", []).size() > 0, "%s/%s/%s not a dead end" % [f, id, nid])
				for c in n.get("choices", []):
					ok(nodes.has(c["next"]), "%s/%s/%s -> %s" % [f, id, nid, c["next"]])
					if c.has("evidence"): ok(ev.has(c["evidence"]), "evidence card %s" % c["evidence"])
			ok(ends, "%s/%s can end" % [f, id])
	for h in ["jo", "tobi", "grange_night", "playhouse_night", "mags", "practice_night", "delphine", "vern", "town_hall_vault", "wmrc_archive"]:
		var home: Dictionary = Data.load_json("homes/%s.json" % h)
		ok(home["items"].size() >= 8, "%s has items" % h)
		for it in home["items"]:
			if it.has("evidence"): ok(ev.has(it["evidence"]), "%s/%s evidence card %s" % [h, it["id"], it["evidence"]])
	for spot in Data.load_json("eavesdrop.json")["tobi_day"]["spots"]:
		if spot.has("evidence"): ok(ev.has(spot["evidence"]), "eavesdrop card %s" % spot["evidence"])
	# days.json references exist
	var days: Dictionary = Data.load_json("days.json")
	for d in days:
		ok(FileAccess.file_exists("res://data/" + days[d]["home"]), "day %s home exists" % d)
		ok(FileAccess.file_exists("res://data/" + days[d]["night"]), "day %s night exists" % d)

	# Honesty Pull: fibs accumulate; at 100 the truth blurts out
	var g := GameState.new()
	var d := Dialogue.new()
	d.start(g, "day03.json", "adaeze")
	d.choose(0)    # "I already ate" (lie 60)
	ok(g.honesty_pull == 60, "first fib adds 60")
	d.choose(0)    # "I ate the cereal that's in my head" (lie 40) -> 100 -> blurt
	ok(g.honesty_pull == 40, "the pull resets after the blurt")
	ok(d.current()["speaker"] == "Tobi" and d.current()["text"].contains("WREN"), "the truth blurts out")
	d.choose(0)
	ok(d.finished or d.current().get("end", false), "the blurt is followed by the end")
	ok(g.suspicion.get_s("adaeze") >= 30, "and Adaeze noticed")
	# an honest child never blurts, and tells the truth for a price in suspicion
	var h := GameState.new()
	var d2 := Dialogue.new()
	d2.start(h, "day03.json", "adaeze")
	d2.choose(2)
	ok(h.honesty_pull == 0 and not d2.finished, "toast-first is calm")
	# Eavesdrop
	var e := Eavesdrop.new("tobi_day")
	ok(e.block_reason("porch") == "locked", "Roy's hedge is locked before the school vent")
	ok(e.listen("kitchen")["ok"] and e.budget == 3, "listening spends time")
	ok(not e.listen("kitchen")["ok"], "can't hear the same thing twice")
	ok(e.listen("vent")["ok"], "school vent")
	ok(e.listen("porch")["ok"], "hedge unlocks after the vent")
	ok(e.listen("dock")["ok"] and e.budget == 0, "last of the budget")
	ok(e.listen("hall")["reason"] == "no_time", "out of time: the day ends")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
