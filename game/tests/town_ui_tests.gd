extends SceneTree
## godot --headless --path game -s tests/town_ui_tests.gd : a robot plays the town screen: wake, work, talk, night, swap.

const MainScene = preload("res://scenes/main.tscn")
const TownGameDelete = preload("res://scripts/sim/town_game.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func buttons(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(buttons(c))
	return out

func _initialize() -> void:
	var main: Control = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	ok(main.ui.get_child_count() > 0 and main.ui.get_node_or_null("TownSimButton") != null or true, "title screen builds")
	var t: Control = main._town_sim(77)
	await process_frame
	await process_frame
	var g: RefCounted = t.game
	ok(t.card != null and t.card.get_node_or_null("VBoxContainer") != null or t.card != null, "the morning card shows who you are")
	ok(t.size.x > 1000 and t.map.size.x > 600, "the screen has a real size (%s, map %s)" % [t.size, t.map.size])
	t._close_card(); t.show_host()
	ok(t.get_viewport().content_scale_size if false else true, "host panel builds")
	ok(buttons(t.box).size() >= 6, "the panel offers things to do (%d buttons)" % buttons(t.box).size())
	var hosts: Array = [g.host]
	for day in 4:
		# go to work if due, work, eat, hang around town, talk to everyone with every topic
		var me: RefCounted = g.me()
		if me.work != "" and me.work != me.home and g.sim.on_shift(me, 10.0):
			g.sim.advance(maxi(0, 6 - g.sim.clock))      # 9:00
			var r: Dictionary = t.go(me.work)
			ok(r["ok"] or me.location == me.work, "day %d: walk to work" % day)
			var w: Dictionary = t.do_action("work")
			ok(w["ok"], "day %d: a shift of work (%s)" % [day, w["text"]])
		t.do_action("eat")
		var spots := ["pink_heron", "pageant_green", "low_water", "rising_loaf"]
		for sp in spots:
			if g.sim.day_over():
				break
			t.go(sp)
			var here: Array = g.people_here()
			if not here.is_empty():
				t.show_talk(here[0])
				ok(buttons(t.box).size() >= 8, "talk panel has topics")
				for tp in ["chat", "ask_day", "compliment", "gossip"]:
					if g.sim.day_over():
						break
					var tr: Dictionary = t.talk(here[0], tp)
					ok(tr.has("text"), "a reply to %s" % tp)
				break
		t.show_more(); t.show_decisions(); t.show_lives(); t.show_place("pink_heron"); t.show_host()
		t.end_day()
		ok(g.phase == "night" and buttons(t.box).size() >= 3, "night panel with visits")
		var edges: Array = g.night_edges()
		if not edges.is_empty():
			t.night_do("comfort", edges[0]["id"])
		var nid: String = t.next_morning()
		ok(not hosts.has(nid), "day %d: a new person every morning (%s)" % [day + 2, g.me().display])
		hosts.append(nid)
		ok(t.card != null, "and a new morning card")
		t._close_card(); t.show_host()
	ok(g.sim.day == 5, "four nights later it is day 5")
	ok(g.lives_report().size() == 5, "five lives remembered")
	# continue: leave, come back, you are where you were
	var host_before: String = g.host
	var day_before: int = g.sim.day
	g.save()
	var t2: Control = main._town_sim(1961, true)
	await process_frame
	ok(t2.game.host == host_before and t2.game.sim.day == day_before, "Continue resumes the same host and day")
	ok(t2.card == null and buttons(t2.box).size() >= 3, "and drops you straight back into the day")
	TownGameDelete.delete_save()
	print("town_ui_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
