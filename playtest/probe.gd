extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
func _initialize() -> void:
	var g = DG.new(5)
	var c: Dictionary = g.case
	for k in c: print(k, " = ", str(c[k]).substr(0, 160))
	g.save("user://pt2.json")
	var lg = DG.load_detective("user://pt2.json")
	var a: Dictionary = g.to_dict(); var b: Dictionary = lg.to_dict()
	for k in a:
		if JSON.stringify(a[k]) != JSON.stringify(b.get(k)):
			print("DIFF top ", k, " ", JSON.stringify(a[k]).length(), " ", JSON.stringify(b.get(k)).length())
			if a[k] is Dictionary:
				for k2 in a[k]:
					if JSON.stringify(a[k][k2]) != JSON.stringify(b[k].get(k2)): print("   sub ", k2, " ", JSON.stringify(a[k][k2]).substr(0,200), " || ", JSON.stringify(b[k].get(k2)).substr(0,200))
	quit()
