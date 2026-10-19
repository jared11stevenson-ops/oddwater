extends SceneTree
## godot --headless --path game -s tests/tutorial_tests.gd
## Day 1 is a normal day in your own body. It must PLANT the clues (fair play) without NAMING them (subtle).

const Data = preload("res://scripts/core/data.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
const Persona = preload("res://scripts/core/persona.gd")
const World = preload("res://scripts/sim/sim_world.gd")
var fails := 0
var checks := 0

# Words that would tell the player what is going on. None may appear in the tutorial.
const GIVEAWAYS := ["swap", "swapped", "body", "bodies", "host", "the cause", "taken", "vanish", "switch", "possess", "your mind", "someone else's life", "investigator", "culprit", "kidnap"]
# What a sharp player should be able to piece together from Day 1 alone.
const REQUIRED_BEATS := ["visiting", "clock", "decision", "restless", "thin_weeks", "same_time", "notebook", "pets_know", "wave"]

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func whole_word(text: String, word: String) -> bool:
	var re := RegEx.new()
	re.compile("\\b" + word + "\\b")
	return re.search(text) != null


func all_tutorial_text() -> Array:
	var out: Array = []
	var convos: Dictionary = Data.load_json("convos/day00.json")
	for id in convos:
		for nid in convos[id]["nodes"]:
			var n: Dictionary = convos[id]["nodes"][nid]
			out.append(n["text"])
			out.append(n.get("aside", ""))
			for c in n.get("choices", []):
				out.append(c["text"])
	var home: Dictionary = Data.load_json("homes/player.json")
	out.append(home["intro"])
	for it in home["items"]:
		out.append(it["text"])
		out.append(it["label"])
	var ev: Dictionary = Data.load_json("evidence.json")
	for id in ev:
		if id.begins_with("LF-T"):
			out.append(ev[id]["text"])
	return out

func _initialize() -> void:
	# ---- every foreshadow beat is planted somewhere in Day 1
	var found := {}
	var convos: Dictionary = Data.load_json("convos/day00.json")
	for id in convos:
		for nid in convos[id]["nodes"]:
			if convos[id]["nodes"][nid].has("foreshadow"):
				found[convos[id]["nodes"][nid]["foreshadow"]] = true
	for it in Data.load_json("homes/player.json")["items"]:
		if it.has("foreshadow"):
			found[it["foreshadow"]] = true
	for b in REQUIRED_BEATS:
		ok(found.has(b), "Day 1 plants the '%s' beat" % b)
	# ---- ...and none of them is named
	for text in all_tutorial_text():
		var low := String(text).to_lower()
		for w in GIVEAWAYS:
			ok(not whole_word(low, w), "tutorial text must not say '%s': \"%s\"" % [w, low.left(70)])
	# ---- the night prelude plants the ribbon and the 4:12 minute, also without naming anything
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lines: Array = main._prelude_lines({})
	var prelude: String = " ".join(lines).to_lower()
	ok(prelude.contains("ribbon") and prelude.contains("4:12") and prelude.contains("clock"), "the 3 a.m. scene shows the ribbon and the 4:12 stop")
	for w in GIVEAWAYS:
		ok(not whole_word(prelude, w), "the prelude must not say '%s'" % w)
	ok(lines.size() == 6, "six beats")
	# ---- the pattern the detective later spots: everyone you become ALSO decided the night before
	var homes_with_artifact := 0
	for h in ["mags", "jo", "tobi", "delphine", "vern"]:
		var home: Dictionary = Data.load_json("homes/%s.json" % h)
		var has := false
		for it in home["items"]:
			if it.get("decision_artifact", false):
				has = true
		ok(has, "%s's home holds a trace of the Decision they made the night before" % h)
		homes_with_artifact += 1 if has else 0
	ok(homes_with_artifact == 5, "so the player's own Decision is the first of a pattern")
	# ---- other bodies' pets behave strangely around you; yours (Day 1) is perfectly normal
	var strange := 0
	for h in ["mags", "jo", "tobi", "delphine", "vern"]:
		for it in Data.load_json("homes/%s.json" % h)["items"]:
			if it["kind"] == "pet":
				strange += 1
	ok(strange == 5, "every host has a pet that reacts to you")
	var stray: Dictionary = {}
	for it in Data.load_json("homes/player.json")["items"]:
		if it["id"] == "cat":
			stray = it
	ok(stray.get("text", "").contains("purring") and stray.get("foreshadow", "") == "pets_know", "your own day's cat is perfectly normal: the contrast is the clue")
	# ---- the tutorial costs nothing: you are always yourself in your own body
	var g := GameState.new()
	g.persona = Persona.make("Sam", "she", "dry", "")
	var d := Dialogue.new()
	d.start(g, "day00.json", "billie")
	d.choose(0); d.choose(0); d.choose(0)
	ok(g.suspicion.get_s("billie") == 0 and g.cover_lines == 0 and g.self_lines == 0, "no suspicion, no cover, nothing to track on Day 1")
	# ---- all three Decisions are real Decisions; any of them gets your body Taken at 4:12
	for action in ["sign_lease", "take_job", "confess"]:
		var w := World.new(5)
		w.start_day(); w.take_control("player")
		var r: Dictionary = w.player_act("player", action)
		ok(r["decision"], "%s is a Decision" % action)
		w.release_control(); w.simulate_rest_of_day()
		var gone: Array = w.slack()
		ok(gone == ["player"] and w.people["player"].taken and not w.people["player"].struck, "%s: your body is Taken (not Struck)" % action)
		ok(not w.people["player"].walkon, "and nobody carries on as you")
	# ---- the creator's choices show up in Day 1's own words
	var p = Persona.make("Rowan", "he", "wry", "Noted.")
	ok(p.inner("{you} sighs. {subj} always does.").begins_with("Rowan sighs. he"), "inner voice uses the creator's name and pronouns")
	# ---- Day 1 has no board, no Long Night, no Remnant: a clean, short tutorial
	var def: Dictionary = Data.load_json("days.json")["0"]
	ok(def["night"] == "" and def["night_board"] == false and def["night_event"]["type"] == "prelude", "the tutorial night is the prelude")
	ok(def["perform"].any(func(s): return s.get("kind", "") == "photo") and def["perform"].any(func(s): return s.get("kind", "") == "decision"), "the Notebook and the Decision are taught")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
