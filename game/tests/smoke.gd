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
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails, " day=", s.day, " seals=", s.board.seals.keys(), " evidence=", s.board.evidence.size())
	quit(fails)
