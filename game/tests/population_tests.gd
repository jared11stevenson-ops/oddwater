extends SceneTree
## godot --headless --path game -s tests/population_tests.gd : the everyday town. ~190 people, similar but different lives.

const World = preload("res://scripts/sim/sim_world.gd")
const TownLayout = preload("res://scripts/core/town_layout.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var w := World.new(21, true)
	var layout := TownLayout.new()
	var n := w.people.size()
	ok(n >= 150 and n <= 260, "a town of a sensible size: %d people" % n)
	var gen: Array = w.order.filter(func(id): return w.people[id].walkon and id.begins_with("r"))
	ok(gen.size() >= 120, "plenty of everyday residents: %d" % gen.size())
	# determinism and variety
	var w2 := World.new(21, true)
	ok(w.order == w2.order and w.people[gen[10]].display == w2.people[gen[10]].display and w.people[gen[10]].job == w2.people[gen[10]].job, "same seed, same town")
	var w3 := World.new(22, true)
	ok(w3.people[gen[10]].display != w.people[gen[10]].display or w3.people[gen[10]].job != w.people[gen[10]].job, "a different seed makes a different town")
	# everyone is placed on the map, no duplicate names
	var names: Dictionary = {}
	var missing: Array = []
	var homes: Dictionary = {}
	for id in w.order:
		var p: RefCounted = w.people[id]
		names[p.display] = true
		for loc in [p.home, p.work]:
			if loc != "" and not layout.by_id.has(loc):
				missing.append(loc)
		homes[p.home] = homes.get(p.home, 0) + 1
	ok(missing.is_empty(), "every home and workplace is on the map: %s" % [missing.slice(0, 3)])
	ok(names.size() == n, "no two residents share a name (%d of %d)" % [names.size(), n])
	# households: every generic house is occupied, sizes vary
	var houses: Array = layout.lots.filter(func(l): return l["kind"] == "house")
	var empty := 0
	var sizes: Dictionary = {}
	for h in houses:
		if not homes.has(h["id"]):
			empty += 1
		else:
			sizes[homes[h["id"]]] = true
	ok(empty == 0, "no empty houses (%d of %d)" % [empty, houses.size()])
	ok(sizes.size() >= 3, "households of different sizes: %s" % [sizes.keys()])
	# ages and roles
	var kids := 0; var elders := 0; var students_at_school := true; var retired_work := true
	var jobs: Dictionary = {}
	var hobbies: Dictionary = {}
	var haunt_sets: Dictionary = {}
	for id in gen:
		var p: RefCounted = w.people[id]
		jobs[p.job] = true
		hobbies[p.hobby] = true
		haunt_sets[str(p.haunts)] = true
		if p.group == "child" or p.group == "teen":
			kids += 1
			students_at_school = students_at_school and p.work == "school" and p.age < 18
		if p.group == "elder":
			elders += 1
			retired_work = retired_work and not p.employed
	ok(kids >= 25 and elders >= 15, "children and elders live here too (%d kids, %d elders)" % [kids, elders])
	ok(students_at_school and retired_work, "kids go to school, elders are retired")
	ok(jobs.size() >= 40, "many different jobs: %d" % jobs.size())
	ok(hobbies.size() >= 10, "many different hobbies: %d" % hobbies.size())
	ok(haunt_sets.size() >= 60, "people haunt different places: %d distinct sets" % haunt_sets.size())
	# a Monday and a Sunday
	var w4 := World.new(21, true)
	w4.start_day()
	for t in range(0, 16):
		w4.step_tick(t)      # 6:00 .. 14:00
	var at_work := 0; var due := 0
	for id in gen:
		var p: RefCounted = w4.people[id]
		if w4.on_shift(p, 13.0) and p.work != p.home:
			due += 1
			if p.location == p.work:
				at_work += 1
	ok(due > 40, "on a Monday lots of people are due at work at 1pm (%d)" % due)
	ok(float(at_work) / maxf(due, 1) > 0.45, "and many of them are there (%d of %d)" % [at_work, due])
	var w5 := World.new(21, true)
	w5.day = 7           # Sunday
	w5.start_day()
	var due_sun := 0
	for id in gen:
		if w5.on_shift(w5.people[id], 13.0) and w5.people[id].work != w5.people[id].home:
			due_sun += 1
	ok(due_sun < due * 0.7, "on Sunday fewer people work (%d vs %d)" % [due_sun, due])
	# a whole week
	var wk := World.new(21, true)
	var theft := 0
	for d in 7:
		wk.start_day()
		wk.simulate_rest_of_day()
		wk.slack()
	var starving := 0; var happy := 0; var worked_money := 0
	for id in gen:
		var p: RefCounted = wk.people[id]
		if float(p.needs["hunger"]) < 5.0:
			starving += 1
		if p.mood() > 45.0:
			happy += 1
	ok(starving < gen.size() * 0.1, "after a week almost nobody is starving: %d" % starving)
	ok(happy > gen.size() * 0.4, "and many are doing fine: %d of %d" % [happy, gen.size()])
	# relationships exist, and people have friends
	var withfriends := 0
	for id in gen:
		if w.people[id].rel.size() >= 2:
			withfriends += 1
	ok(withfriends > gen.size() * 0.8, "almost everyone knows a few people: %d" % withfriends)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("  (build + a week of %d people took %.1fs)" % [n, secs])
	ok(secs < 90.0, "fast enough")
	print("population_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
