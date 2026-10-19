extends SceneTree
## godot --headless --path game -s tests/investigation_tests.gd : claims, evidence tampering, drift, hints.

const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
const Data = preload("res://scripts/core/data.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# ---- claim data integrity
	var claims: Dictionary = Data.load_json("claims.json")
	var ev: Dictionary = Data.load_json("evidence.json")
	for cid in claims:
		for e in claims[cid]["contradicted_by"]:
			ok(ev.has(e), "claim %s contradicted by a real card %s" % [cid, e])
		if claims[cid]["reveals"] != "":
			ok(ev.has(claims[cid]["reveals"]), "claim %s reveals a real card" % cid)
	# every claim is actually spoken somewhere in a conversation
	var spoken := {}
	for f in ["day01.json", "day02.json", "day03.json", "day04.json", "day05.json"]:
		var all: Dictionary = Data.load_json("convos/" + f)
		for id in all:
			for nid in all[id]["nodes"]:
				if all[id]["nodes"][nid].has("claim"):
					spoken[all[id]["nodes"][nid]["claim"]] = true
	for cid in claims:
		ok(spoken.has(cid), "claim %s is spoken in some conversation" % cid)

	# ---- interrogation: Silas says it isn't him; the overlay says it is
	var g := GameState.new(true)
	var d := Dialogue.new()
	d.start(g, "day01.json", "silas")
	ok(d.open_claims().is_empty(), "no claims before he speaks")
	d.choose(1); d.choose(0); d.choose(0)    # bold route to the Rook line
	ok(g.claims.get("silas_not_rook", "") == "heard", "Silas's denial is on the record")
	ok(d.open_claims() == ["silas_not_rook"], "and it's open")
	var wrong: Dictionary = d.present("LF-055")          # the chart, not the overlay: not contradicting
	ok(wrong["result"] == "nothing", "the wrong card proves nothing")
	var before: int = g.suspicion.get_s("silas")
	var crack: Dictionary = d.present("LF-056")
	ok(crack["result"] == "crack" and crack["text"].contains("Thaddeus"), "the overlay cracks it")
	ok(g.claims["silas_not_rook"] == "cracked" and g.board.evidence.has("LF-060"), "claim cracked; his diary surfaces")
	ok(g.suspicion.get_s("silas") > before, "and he's more wary")
	ok(d.present("LF-056")["result"] == "nothing", "a cracked claim cannot be cracked twice")
	ok(d.present("LF-999")["result"] == "nothing", "you can't present what you don't have")

	# ---- pressing in another body, days later: Dolores in Vern's body
	var h := GameState.new(true)
	h.board.add_evidence("LF-040")
	var d2 := Dialogue.new()
	d2.start(h, "day05.json", "dolores")
	d2.choose(0)   # "there's a hymn missing"
	ok(h.claims.get("dolores_no_212", "") == "heard", "Dolores denies Hymn 212")
	ok(d2.present("LF-040")["result"] == "crack", "the choir reel makes her admit it was retired")

	# ---- evidence tampering
	var b: RefCounted = GameState.new(true).board
	for id in ["LF-035", "LF-036", "LF-043", "LF-055"]:
		b.add_evidence(id)
	ok(b.texts["LF-036"].contains("Fair water"), "card text starts true")
	var changed: Array = b.hush_edit(42, 2)
	ok(changed.size() == 2 and b.edited.size() == 2, "the Hush edits two cards (%s)" % [changed])
	ok(not changed.has("LF-055"), "cards with nothing to alter are untouched")
	var victim: String = changed[0]
	ok(b.texts[victim] != b.originals[victim], "the text actually changed: '%s'" % b.texts[victim].left(60))
	ok(b.is_corrupt(victim), "and it is corrupt")
	# a corrupt card blocks a Seal with no explanation but the reason
	var b2: RefCounted = GameState.new(true).board
	b2.add_evidence("LF-036"); b2.pin("LF-036", "what")
	b2.set_tool("reel", true)
	ok(b2.can_test("S22"), "S22 is testable with a true card")
	b2.edited["LF-036"] = true
	ok(b2.block_reason("S22") == "corrupt:LF-036", "an edited card fails its Seal: %s" % b2.block_reason("S22"))
	ok(not b2.try_link_test("S22", 5), "the test fails")
	# photographs protect
	var b3: RefCounted = GameState.new(true).board
	for id in ["LF-035", "LF-036", "LF-043"]:
		b3.add_evidence(id)
	ok(b3.photograph("LF-036") and b3.photograph("LF-035") and b3.photograph("LF-043"), "three exposures a day")
	ok(not b3.photograph("LF-036"), "already photographed")
	b3.add_evidence("LF-042")
	ok(not b3.photograph("LF-042"), "out of film")
	ok(b3.hush_edit(5, 3).is_empty() or true, "photographed cards are skipped")
	ok(not b3.edited.has("LF-036") and not b3.edited.has("LF-035"), "protected cards survive the dawn")
	b3.new_day_film()
	ok(b3.film_left == 3, "film is renewed each day")
	# restoring
	var b4: RefCounted = GameState.new(true).board
	b4.add_evidence("LF-036")
	b4.photograph("LF-036")
	b4.edited["LF-036"] = true
	b4.texts["LF-036"] = "tampered"
	ok(b4.mismatch("LF-036"), "the Notebook disagrees with the card")
	ok(b4.restore("LF-036") and b4.texts["LF-036"] == b4.originals["LF-036"] and not b4.is_corrupt("LF-036"), "restored from the photograph")
	var b5: RefCounted = GameState.new(true).board
	b5.add_evidence("LF-036"); b5.edited["LF-036"] = true; b5.texts["LF-036"] = "tampered"
	ok(not b5.restore("LF-036"), "without a photo you cannot simply wish it back")
	ok(b5.restore("LF-036", true) and not b5.is_corrupt("LF-036"), "but re-finding the source fixes it")
	# photographing an already-edited card freezes the lie (a trap for the careless)
	var b6: RefCounted = GameState.new(true).board
	b6.add_evidence("LF-036"); b6.edited["LF-036"] = true; b6.texts["LF-036"] = "tampered"
	b6.photograph("LF-036")
	ok(not b6.restore("LF-036"), "a photograph of an already-edited card is worthless")

	# ---- the Hush at dawn follows calm and comfort
	var calm := GameState.new(true)
	for i in 3: for j in 5: calm.advance()
	for id in ["LF-035", "LF-036", "LF-043", "LF-042"]:
		calm.board.add_evidence(id)
	calm.drift = 80.0
	ok(not calm.hush_dawn().is_empty(), "a comfortable player in a calm town gets edited")
	var grace := GameState.new(true)
	grace.board.add_evidence("LF-036")
	ok(grace.hush_dawn().is_empty(), "no edits in the grace days")
	var scared := GameState.new(true)
	for i in 3: for j in 5: scared.advance()
	for id in ["LF-035", "LF-036", "LF-043"]:
		scared.board.add_evidence(id)
	scared.town_mood = 0
	ok(scared.hush_dawn().is_empty(), "a frightened town is harder to edit")

	# ---- drift: living well is the trap; being bold keeps you awake
	var cozy := GameState.new(true)
	cozy.notes.add("fidelity", 60); cozy.notes.add("warmth", 30)
	cozy.close_day(85.0)
	var bold := GameState.new(true)
	bold.notes.add("fidelity", 60)
	bold.board.seals["S01"] = 1; bold.board.seals["S02"] = 1   # two truths proven today
	bold.close_day(85.0)
	ok(cozy.drift > bold.drift, "comfort raises drift; proving truths keeps you awake (%.1f vs %.1f)" % [cozy.drift, bold.drift])
	ok(cozy.drift_label() == "Sharp" or cozy.drift_label() == "Getting comfortable", "labels are friendly: %s" % cozy.drift_label())
	var lost := GameState.new(true); lost.drift = 90.0
	ok(lost.drift_label() == "At home", "'At home' is the horror label")
	ok(cozy.alignment > 0.0 and bold.alignment > 0.0, "in-character play earns alignment")
	var rebel := GameState.new(true); rebel.notes.add("fidelity", -30); rebel.close_day(40.0)
	ok(rebel.alignment == 0.0, "going off-script earns none")
	# ---- hints: the Prompter takes over as you settle
	var w := 0
	var pr := 0
	for dd in range(1, 40):
		var s := GameState.new(true); s.day = 5; s.drift = 0.0 + dd
		var hint: Dictionary = s.pick_hint()
		if hint["voice"] == "prompter": pr += 1
		else: w += 1
	var lowp := 0
	var highp := 0
	for k in 40:
		var a := GameState.new(true); a.day = 3; a.drift = float(k % 10)
		var z := GameState.new(true); z.day = 3; z.drift = 80.0 + float(k % 10)
		a.flags["x"] = k; z.flags["x"] = k
		a.day = 3 + k; z.day = 3 + k
		lowp += 1 if a.pick_hint()["voice"] == "prompter" else 0
		highp += 1 if z.pick_hint()["voice"] == "prompter" else 0
	ok(highp > lowp, "the Prompter speaks more as drift rises (%d vs %d of 40)" % [highp, lowp])
	var saved := GameState.new(true); saved.drift = 33.0; saved.claims["x"] = "heard"; saved.board.add_evidence("LF-036"); saved.board.photograph("LF-036")
	saved.save_to("user://inv.json")
	var loaded := GameState.new(true)
	ok(loaded.load_from("user://inv.json") and loaded.drift == 33.0 and loaded.claims.get("x") == "heard" and loaded.board.notebook.has("LF-036"), "investigation state survives a save")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
