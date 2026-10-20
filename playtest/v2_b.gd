extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
func diff(a, b, path := "") -> void:
	if typeof(a) != typeof(b): print("TYPE ", path, " ", typeof(a), " ", typeof(b), " ", str(a).substr(0,60), " | ", str(b).substr(0,60)); return
	if a is Dictionary:
		for k in a: 
			if not b.has(k): print("MISSING ", path, "/", k)
			else: diff(a[k], b[k], path + "/" + str(k))
		for k in b: if not a.has(k): print("EXTRA ", path, "/", k)
	elif a is Array:
		if a.size() != b.size(): print("SIZE ", path, a.size(), b.size()); return
		for i in a.size(): diff(a[i], b[i], path + "[" + str(i) + "]")
	elif a != b: print("VAL ", path, " ", str(a).substr(0,60), " | ", str(b).substr(0,60))
func _initialize() -> void:
	var g = DG.new(101)
	var pre = Bot.new(g.sim, g.case, g.det); pre.examine_scene(); pre.interview(g.case["found_by"])
	g.save("user://x.json"); var l = DG.load_detective("user://x.json")
	var n := 0
	diff(JSON.parse_string(JSON.stringify(g.to_dict())), JSON.parse_string(JSON.stringify(l.to_dict())))
	print("---- serial 110")
	for s in [110, 120]:
		var h = DG.new(s, "", true)
		var b = Bot.new(h.sim, h.case, h.det); var r = b.solve()
		print(s, " ", r["result"]["verdict"], " ", r["result"].get("cats"), " total ", r["result"].get("total"), " accused ", r["accused"], " killer ", h.case["killer"])
		var res = h.accuse(h.case["killer"], h.case["motive"], h.case["method"])
		print(str(res).substr(0,500)); print("jail ", h.jail.size())
		print("OBJ ", h.objective())
	quit()
