extends SceneTree
## godot --headless --path game -s tests/smoke.gd
## A robot plays Days 1, 2 and 3 through the real UI. Checks the story state at every dawn.

const Bot = preload("res://tests/bot.gd")
var fails := 0

func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_day()
	var bot := Bot.new(main, self)
	check(await bot.play_until_day(2), "reached Day 2: %s" % [bot.log])
	var s: RefCounted = main.state
	check(s.current_life()["id"] == "jo", "Day 2 is Jo")
	check(s.board.seals.has("S25") and s.board.seals.has("S23"), "Day 1 seals: %s" % [s.board.seals.keys()])
	check(s.remnants.has_remnant("mags"), "Mags remnant")
	check(await bot.play_until_day(3), "reached Day 3: %s" % [bot.log])
	check(s.current_life()["id"] == "tobi", "Day 3 is Tobi")
	check(s.board.seals.has("S20"), "Reply answered: S20 sealed (%s)" % [s.board.seals.keys()])
	check(s.board.evidence.has("LF-047") and s.board.evidence.has("LF-024"), "Jo's evidence")
	check(s.remnants.has_remnant("jo"), "Jo remnant")
	check(await bot.play_until_day(4), "reached Day 4: %s" % [bot.log])
	check(s.board.seals.has("S29"), "Prompt Book exists: S29 sealed (%s)" % [s.board.seals.keys()])
	check(s.board.evidence.has("LF-052") and s.board.evidence.has("LF-075"), "Tobi's evidence")
	check(s.remnants.has_remnant("tobi"), "Tobi remnant")
	check(s.board.seals.size() >= 4, "four seals by Day 4: %d" % s.board.seals.size())
	check(await bot.play_until_day(5), "reached Day 5: %s" % [bot.log])
	check(s.current_life()["id"] == "vern", "Day 5 is Vern")
	check(s.board.seals.has("S17") and s.board.seals.has("S16"), "Delphine's vault proves S17 and S16 (%s)" % [s.board.seals.keys()])
	check(s.flags.get("delphine_resigned", false), "the bold speech announced the resignation")
	check(s.remnants.has_remnant("delphine"), "Delphine remnant")
	check(await bot.play_until_day(6), "reached Day 6: %s" % [bot.log])
	check(s.board.seals.has("S12"), "the dedications spell FAIR WATER: S12 (%s)" % [s.board.seals.keys()])
	check(s.board.seals.has("S22") and s.board.seals.has("S21"), "the reel proves the last broadcast and the missing hymn (%s)" % [s.board.seals.keys()])
	check(s.flags.get("hymn_aired", false) and s.is_foggy() == (s.town_mood < 30), "the bot aired the hymn (first button) and the town got afraid: mood %d" % s.town_mood)
	check(s.remnants.has_remnant("vern"), "Vern remnant")
	# ---- the same five days again with a careless player: the Hush should hurt
	var main2: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main2)
	await process_frame
	main2.start_day()
	var sloppy := Bot.new(main2, self, false)
	check(await sloppy.play_until_day(6), "careless run reached Day 6: %s" % [sloppy.log])
	var s2: RefCounted = main2.state
	var corrupt := 0
	for id in s2.board.evidence.keys():
		if s2.board.is_corrupt(id): corrupt += 1
	check(corrupt >= 1, "the careless detective's case file has been tampered with (%d corrupt cards)" % corrupt)
	check(s2.board.seals.size() <= s.board.seals.size(), "and proves no more than the careful one (%d vs %d)" % [s2.board.seals.size(), s.board.seals.size()])
	var careful_corrupt := 0
	for id in s.board.evidence.keys():
		if s.board.is_corrupt(id): careful_corrupt += 1
	check(careful_corrupt <= corrupt, "the careful one is no worse off (%d vs %d corrupt)" % [careful_corrupt, corrupt])
	check(s.claims.values().has("cracked"), "the careful detective cracked at least one claim: %s" % [s.claims])
	check(s2.board.seals.size() < s.board.seals.size(), "the Hush cost the careless detective Seals (%d vs %d)" % [s2.board.seals.size(), s.board.seals.size()])
	# ---- and a comfortable player who lives the life and skips the investigating
	var main3: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main3)
	await process_frame
	main3.start_day()
	var cozy := Bot.new(main3, self, false)
	cozy.dull = true
	check(await cozy.play_until_day(6), "comfortable run reached Day 6: %s" % [cozy.log])
	var s3: RefCounted = main3.state
	check(s3.drift > s.drift + 5.0, "comfort is the trap: drift %.1f (comfortable) vs %.1f (detective)" % [s3.drift, s.drift])
	check(s3.board.seals.size() < s.board.seals.size(), "and the comfortable player has solved far less (%d vs %d seals)" % [s3.board.seals.size(), s.board.seals.size()])
	# ---- STEER: with the Long Night, the player chooses who they wake up as
	var main4: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main4)
	await process_frame
	main4.start_day()
	var steerer := Bot.new(main4, self, true)
	steerer.steer_to = "tobi"
	check(await steerer.play_until_day(2), "steering run reached Day 2: %s" % [steerer.log])
	check(main4.state.current_life()["id"] == "tobi", "the detective steered tomorrow's host from Jo to Tobi (got %s)" % main4.state.current_life()["id"])
	check(main4.state.host_history == ["mags", "tobi"], "history: %s" % [main4.state.host_history])
	steerer.steer_to = "delphine"
	check(await steerer.play_until_day(3), "steered again: %s" % [steerer.log])
	check(main4.state.current_life()["id"] == "delphine", "and again, to Delphine, skipping Jo (%s)" % main4.state.current_life()["id"])
	var baseline_hosts: Array = s.host_history
	check(baseline_hosts.slice(0, 5) == ["mags", "jo", "tobi", "delphine", "vern"], "unsteered, the authored order holds: %s" % [baseline_hosts])
	print("careful: seals=%d corrupt=%d drift=%.1f | careless: seals=%d corrupt=%d drift=%.1f | comfortable: seals=%d drift=%.1f label=%s" % [s.board.seals.size(), careful_corrupt, s.drift, s2.board.seals.size(), corrupt, s2.drift, s3.board.seals.size(), s3.drift, s3.drift_label()])
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails, " day=", s.day, " seals=", s.board.seals.keys(), " evidence=", s.board.evidence.size())
	quit(fails)
