extends SceneTree
## godot --headless --path game -s tests/town_tests.gd

const Town = preload("res://scripts/core/town_layout.gd")
const Data = preload("res://scripts/core/data.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var t := Town.new()
	var ref: Dictionary = t.spec["reference_south_park"]
	var mult: float = ref["multiplier"]
	var ref_area: float = float(ref["width_m"]) * float(ref["depth_m"])
	var built := t.built_lots()
	print("built lots: %d | land area: %d m2 | reference area (estimate): %d m2" % [built.size(), t.land_area(), ref_area])
	ok(t.land_area() >= ref_area * mult, "land area >= %sx reference" % mult)
	ok(built.size() >= int(ref["lots"] * mult), "built lots >= %sx reference" % mult)
	var ids := {}
	for l in t.lots:
		ok(not ids.has(l["id"]), "unique id %s" % l["id"])
		ids[l["id"]] = true
	# every landmark in the spec was placed
	for lm in t.spec["landmarks"]:
		ok(t.by_id.has(lm["id"]), "placed %s" % lm["id"])
	# every Life has a home lot
	for life in Data.load_json("lives.json"):
		if life["id"] == "prop_room":
			continue
		ok(t.by_id.has(life["id"] + "_home"), "home for %s" % life["id"])
	# no overlaps, all inside bounds
	var b: Dictionary = t.spec["bounds"]
	for i in t.lots.size():
		var a: Dictionary = t.lots[i]
		ok(a["x"] - a["w"] / 2 >= b["x0"] and a["x"] + a["w"] / 2 <= b["x1"] and a["y"] - a["d"] / 2 >= b["y0"] and a["y"] + a["d"] / 2 <= b["y1"], "in bounds %s" % a["id"])
		for j in range(i + 1, t.lots.size()):
			var c: Dictionary = t.lots[j]
			var ox: bool = absf(a["x"] - c["x"]) < (a["w"] + c["w"]) / 2.0 - 0.01
			var oy: bool = absf(a["y"] - c["y"]) < (a["d"] + c["d"]) / 2.0 - 0.01
			ok(not (ox and oy), "no overlap %s / %s" % [a["id"], c["id"]])
	# lake side: nothing north of the shore drive
	for l in t.lots:
		ok(l["y"] > -125.0, "%s is on land" % l["id"])
	var m: Vector2 = t.mirror(Vector2(10, 20))
	ok(t.mirror(m) == Vector2(10, 20), "mirror is reversible")
	print("walk Quay -> Chapel: %.0fs, Marina -> Lakeview Rest: %.0fs" % [t.walk_seconds("launch_quay", "chapel"), t.walk_seconds("marina", "lakeview_rest")])
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
