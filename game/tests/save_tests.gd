extends SceneTree
## godot --headless --path game -s tests/save_tests.gd : the whole town survives being put away.

const TownGame = preload("res://scripts/sim/town_game.gd")
var fails := 0
var checks := 0
const PATH := "user://test_town_save.json"

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func same(a: RefCounted, b: RefCounted) -> bool:
	if a.sim.day != b.sim.day or a.sim.clock != b.sim.clock or a.host != b.host or a.phase != b.phase or a.sim.order != b.sim.order:
		return false
	for id in a.sim.order:
		var p: RefCounted = a.sim.people[id]
		var q: RefCounted = b.sim.people[id]
		if p.location != q.location or p.activity != q.activity or p.memories.size() != q.memories.size() or p.employed != q.employed:
			return false
		if absf(p.money - q.money) > 1e-6:
			return false
		for k in p.needs:
			if absf(float(p.needs[k]) - float(q.needs[k])) > 1e-6:
				return false
		for o in p.rel:
			if not q.rel.has(o) or absf(float(p.rel[o]["affinity"]) - float(q.rel[o]["affinity"])) > 1e-6:
				return false
	return true

func play(g: RefCounted) -> void:
	# the same fixed routine, whoever you are
	g.do("relax", 1.0)
	var here: Array = g.people_here()
	g.go("pink_heron")
	here = g.people_here()
	if not here.is_empty():
		g.talk(here[0], "chat")
	g.act("praise", {"target": here[0]}) if not here.is_empty() else null
	g.do("relax", 2.0)

func _initialize() -> void:
	DirAccess.remove_absolute(PATH)
	var a := TownGame.new(31)
	play(a)
	a.end_day()
	a.night_visit("comfort", a.night_edges()[0]["id"]) if not a.night_edges().is_empty() else null
	a.dawn()
	play(a)
	ok(a.save(PATH) and TownGame.has_save(PATH), "saves to disk")
	var b: RefCounted = TownGame.load_game(PATH)
	ok(b != null, "loads from disk")
	ok(same(a, b), "the loaded town is the saved town")
	ok(b.hosts.size() == a.hosts.size() and b.host == a.host and b.chronicle.size() == a.chronicle.size(), "host history and news survive")
	ok(b.sim.rumors.size() == a.sim.rumors.size(), "rumours survive")
	# the future is the same: play both on identically
	play(a); play(b)
	a.end_day(); b.end_day()
	a.dawn(); b.dawn()
	ok(same(a, b), "a loaded game goes on exactly like the original (deterministic)")
	ok(a.host == b.host and a.sim.day == b.sim.day, "same host tomorrow (%s)" % a.host)
	# mid-day save, mid-night save
	var c := TownGame.new(32)
	c.do("relax", 1.0)
	c.save(PATH)
	var c2: RefCounted = TownGame.load_game(PATH)
	ok(same(c, c2) and c2.phase == "day", "a mid-day save restores the clock")
	c.end_day(); c.save(PATH)
	var c3: RefCounted = TownGame.load_game(PATH)
	ok(c3.phase == "night" and same(c, c3), "a night save restores the night")
	# decisions persist
	var d := TownGame.new(33)
	d.act("quit_job")
	d.save(PATH)
	var d2: RefCounted = TownGame.load_game(PATH)
	ok(d2.me().employed == d.me().employed, "big moves survive a save")
	# bad files
	var f := FileAccess.open(PATH, FileAccess.WRITE); f.store_string("not json at all"); f.close()
	ok(TownGame.load_game(PATH) == null, "a corrupt save loads as nothing, not a crash")
	f = FileAccess.open(PATH, FileAccess.WRITE); f.store_string("{\"version\": 1}"); f.close()
	ok(TownGame.load_game(PATH) == null, "an old save version is refused")
	TownGame.delete_save(PATH)
	ok(not TownGame.has_save(PATH) and TownGame.load_game(PATH) == null, "no save, no game")
	print("save_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
