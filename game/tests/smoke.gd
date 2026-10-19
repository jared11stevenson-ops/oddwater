extends SceneTree
## godot --headless --path game -s tests/smoke.gd
## A robot plays the tutorial day and Act I through the real UI: careful, careless, comfortable, and steering.

const Bot = preload("res://tests/bot.gd")
var fails := 0

func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("  FAIL: ", m)

func fresh(careful: bool = true) -> Array:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_day()
	return [main, Bot.new(main, self, careful)]

func _initialize() -> void:
	var run: Array = await fresh(true)
	var main: Control = run[0]
	var bot = run[1]
	var s: RefCounted = main.state
	# ---- Day 1: your own body, your own day
	check(s.current_life()["id"] == "player" and s.day == 1, "Day 1 is the protagonist")
	check(await bot.play_until_day(2), "finished the tutorial day: %s" % [bot.log])
	check(bot.log.has("tutorial:photo") and bot.log.has("tutorial:decision"), "photo and Decision steps ran: %s" % [bot.log])
	check(s.flags.get("tutorial_decision", "") != "", "you made a Decision on Day 1 (%s)" % s.flags.get("tutorial_decision", ""))
	check(s.board.notebook.size() == 1, "and photographed one thing")
	check(not s.remnants.has_remnant("player"), "no Remnant is made of your own body")
	check(main.sim.people["player"].taken, "your body was taken at 4:12")
	check(s.current_life()["id"] == "mags", "Day 2: you wake up as Mags")
	check(s.host_history == ["player", "mags"], "history %s" % [s.host_history])
	# ---- the first hosts
	check(await bot.play_until_day(3), "reached Day 3: %s" % [bot.log])
	check(s.current_life()["id"] == "jo", "Day 3 is Jo")
	check(s.board.seals.has("S25") and s.board.seals.has("S23"), "Mags's day proved S25 and S23 (%s)" % [s.board.seals.keys()])
	check(await bot.play_until_day(4), "reached Day 4: %s" % [bot.log])
	check(s.current_life()["id"] == "tobi" and s.board.seals.has("S20"), "Day 4 is Tobi; the Reply is answered (S20)")
	check(await bot.play_until_day(5), "reached Day 5: %s" % [bot.log])
	check(s.current_life()["id"] == "delphine" and s.board.seals.has("S29"), "Day 5 is Delphine; the Prompt Book is found (S29)")
	check(await bot.play_until_day(6), "reached Day 6: %s" % [bot.log])
	check(s.current_life()["id"] == "vern" and s.board.seals.has("S17") and s.board.seals.has("S16"), "Day 6 is Vern; the vault proved S17/S16 (%s)" % [s.board.seals.keys()])
	check(s.flags.get("delphine_resigned", false), "the bold speech announced the resignation")
	check(await bot.play_until_day(7), "reached Day 7: %s" % [bot.log])
	check(s.board.seals.has("S12") and s.board.seals.has("S22") and s.board.seals.has("S21"), "Vern's day proved S12, S21, S22")
	check(s.flags.get("hymn_aired", false), "the hymn was aired (first button)")
	check(s.host_history.slice(0, 6) == ["player", "mags", "jo", "tobi", "delphine", "vern"], "unsteered, the authored order holds: %s" % [s.host_history])
	check(s.claims.values().has("cracked"), "the careful detective cracked a claim: %s" % [s.claims])
	# ---- the same days again, carelessly
	var r2: Array = await fresh(false)
	var main2: Control = r2[0]
	var sloppy = r2[1]
	check(await sloppy.play_until_day(7), "careless run reached Day 7: %s" % [sloppy.log])
	var s2: RefCounted = main2.state
	check(s2.board.seals.size() < s.board.seals.size(), "the Hush cost the careless detective Seals (%d vs %d)" % [s2.board.seals.size(), s.board.seals.size()])
	# ---- a comfortable player who lives the lives and skips the case
	var r3: Array = await fresh(false)
	var main3: Control = r3[0]
	var cozy = r3[1]
	cozy.dull = true
	check(await cozy.play_until_day(7), "comfortable run reached Day 7: %s" % [cozy.log])
	var s3: RefCounted = main3.state
	check(s3.drift > s.drift + 5.0, "comfort erodes the self: drift %.1f vs %.1f" % [s3.drift, s.drift])
	check(s3.board.seals.size() < s.board.seals.size(), "and the comfortable player has solved far less (%d vs %d)" % [s3.board.seals.size(), s.board.seals.size()])
	# ---- STEER from Mags's night onward
	var r4: Array = await fresh(true)
	var main4: Control = r4[0]
	var steerer = r4[1]
	check(await steerer.play_until_day(2), "steer run: tutorial done")
	steerer.steer_to = "tobi"
	check(await steerer.play_until_day(3), "steered once: %s" % [steerer.log])
	check(main4.state.current_life()["id"] == "tobi", "the detective steered tomorrow's host from Jo to Tobi (got %s)" % main4.state.current_life()["id"])
	steerer.steer_to = "delphine"
	check(await steerer.play_until_day(4), "steered again")
	check(main4.state.current_life()["id"] == "delphine", "and again, to Delphine, skipping Jo (%s)" % main4.state.current_life()["id"])
	print("careful: seals=%d drift=%.1f | careless: seals=%d drift=%.1f | comfortable: seals=%d drift=%.1f label=%s" % [s.board.seals.size(), s.drift, s2.board.seals.size(), s2.drift, s3.board.seals.size(), s3.drift, s3.drift_label()])
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails, " day=", s.day, " seals=", s.board.seals.keys())
	quit(fails)
