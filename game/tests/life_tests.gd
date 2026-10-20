extends SceneTree
## godot --headless --path game -s tests/life_tests.gd : wishes, relationship stages, weather, market day.

const TownGame = preload("res://scripts/sim/town_game.gd")
const World = preload("res://scripts/sim/sim_world.gd")
const Wishes = preload("res://scripts/sim/wishes.gd")
const Relationship = preload("res://scripts/sim/relationship.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	# relationship stages
	ok(Relationship.stage(90, 80) == "best friend" and Relationship.stage(55, 40) == "close friend" and Relationship.stage(30, 0) == "friend", "friendly stages")
	ok(Relationship.stage(0, 0) == "stranger" and Relationship.stage(10, 0) == "acquaintance", "strangers and acquaintances")
	ok(Relationship.stage(-30, 0) == "rival" and Relationship.stage(-70, -40) == "enemy" and Relationship.stage(-10, 0) == "on bad terms", "unfriendly stages")
	# weather
	var w := World.new(4, true)
	var seen: Dictionary = {}
	for d in range(1, 41):
		w.day = d
		seen[w.weather_today()] = int(seen.get(w.weather_today(), 0)) + 1
	ok(seen.has("clear") and seen.has("rain") and seen.has("cloudy"), "weather varies over forty days: %s" % [seen])
	w.day = 9
	ok(w.weather_today() == w.weather_today(), "weather is deterministic")
	ok(w.event_today() == "" and (World.new(4).event_today() == ""), "an ordinary Monday")
	# the weekly rhythm: market day pulls people to the green
	var mk := World.new(5, true)
	mk.day = 6                      # Saturday
	mk.start_day()
	for t in range(0, 20):
		mk.step_tick(t)             # to 16:00
		if t == 9:                  # 10:30: market day is on
			pass
	var tue := World.new(5, true)
	tue.day = 2
	tue.start_day()
	var at_green_sat := 0
	var at_green_tue := 0
	mk.day = 6; tue.day = 2
	for t in range(8, 14):        # 10:00 - 13:00
		mk.step_tick(t); tue.step_tick(t)
		for id in mk.order:
			if mk.people[id].location == "pageant_green":
				at_green_sat += 1
		for id in tue.order:
			if tue.people[id].location == "pageant_green":
				at_green_tue += 1
	ok(mk.weekday() == 5 and mk.event_today() in ["Market on the green", "Market rained off"], "Saturday is market day")
	ok(at_green_sat > at_green_tue * 1.5 or (at_green_sat > 20 and mk.raining()), "the green fills on Saturday (%d vs %d)" % [at_green_sat, at_green_tue])
	# rain keeps people off the water
	var rain_day := 1
	var clear_day := 1
	for d in range(1, 60):
		w.day = d
		if w.weather_today() == "rain" and rain_day == 1: rain_day = d
		if w.weather_today() == "clear" and w.weekday() < 5 and clear_day == 1: clear_day = d
	var out_rain := 0; var out_clear := 0
	for pair in [[rain_day, "rain"], [clear_day, "clear"]]:
		var ww := World.new(4, true)
		ww.day = pair[0]
		ww.start_day()
		for t in range(10, 30):
			ww.step_tick(t)
			for id in ww.order:
				if ww.OUTDOORS.has(ww.people[id].location):
					if pair[1] == "rain": out_rain += 1
					else: out_clear += 1
	ok(out_rain < out_clear, "fewer people linger outdoors in the rain (%d vs %d)" % [out_rain, out_clear])
	# wishes
	var g := TownGame.new(12)
	ok(g.wishes.size() == 3, "three wishes for the day")
	var kinds: Dictionary = {}
	for x in g.wishes:
		kinds[x["id"]] = true
	ok(kinds.size() == 3, "three different kinds of wish")
	var g2 := TownGame.new(12)
	ok(str(g.wishes) == str(g2.wishes), "wishes are deterministic")
	var pts0 := g.wish_points
	var me: RefCounted = g.me()
	me.money = 500.0
	g.wishes = [{"id": "meal", "text": "Have a proper meal", "done": false, "points": 10}, {"id": "treat", "text": "Treat", "done": false, "points": 10}, {"id": "friend", "text": "Make a friend", "done": false, "points": 10}]
	g.go("pink_heron")
	g.do("eat", 1.0)
	ok(g.wishes[0]["done"] and g.wish_points == pts0 + 10, "eating a meal fulfils the meal wish")
	var purpose_before := float(me.needs["purpose"])
	var here: Array = g.people_here()
	if not here.is_empty():
		g.act("gift", {"target": here[0], "amount": 20})
		ok(g.wishes[1]["done"], "treating someone fulfils the treat wish")
	ok(float(me.needs["purpose"]) >= purpose_before, "wishes lift the spirits")
	g.end_day()
	ok(g.report.has("done") and int(g.report["done"]) >= 1 and g.report["name"] == me.display, "an end-of-day report")
	ok(g.report["news"].size() >= 1, "the report remembers what came true")
	var nid := g.dawn()
	ok(g.wishes.size() == 3 and g.wishes[0]["done"] == false, "fresh wishes next morning, for whoever you now are")
	ok(g.hosts[0].get("wishes_done", 0) >= 1, "the Lives report keeps the tally")
	# a shift wish
	var g3 := TownGame.new(13)
	var worker := ""
	for i in 12:
		if g3.sim.on_shift(g3.me(), g3.me().work_start) and g3.me().work != g3.me().home and g3.me().work != "":
			worker = g3.host
			break
		g3.end_day(); g3.dawn()
	if worker != "":
		g3.wishes = [{"id": "shift", "text": "x", "done": false, "points": 10}]
		g3.sim.advance(maxi(0, int((g3.me().work_start - 6.0) * 2.0) - g3.sim.clock))
		g3.go(g3.me().work)
		g3.do("work", 6.0)
		ok(g3.wishes[0]["done"], "a six-hour shift fulfils the shift wish")
	# persistence of wishes
	var g4 := TownGame.new(14)
	g4.save("user://life_save.json")
	var g5: RefCounted = TownGame.load_game("user://life_save.json")
	ok(g5.wishes.size() == g4.wishes.size() and g5.wishes[0]["text"] == g4.wishes[0]["text"] and g5.wish_points == g4.wish_points, "wishes survive a save")
	TownGame.delete_save("user://life_save.json")
	print("life_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
