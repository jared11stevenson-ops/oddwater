extends RefCounted
## Deterministic, data-driven layout of Little Mercy. Lots sit along E-W streets;
## landmarks and homes claim the nearest free lot; houses fill up to `target_lots`.

const Data = preload("res://scripts/core/data.gd")

var spec: Dictionary
var lots: Array = []        # {id,name,kind,street,side,x,y,w,d,owner?}
var by_id: Dictionary = {}


func _init() -> void:
	spec = Data.load_json("town_spec.json")
	_build()


func _candidates() -> Array:
	var lot: Dictionary = spec["lot"]
	var out: Array = []
	var cross: Array = spec["cross_x"]
	for st in spec["streets"]:
		for side in [-1, 1]:
			if st["id"] == "shore_drive" and side == -1:
				continue   # the lake
			var bounds: Array = [float(st["x0"])] + cross.map(func(v): return float(v)) + [float(st["x1"])]
			var seq := 0
			for i in bounds.size() - 1:
				var a: float = bounds[i] + (float(lot["cross_half"]) if i > 0 else 4.0)
				var b: float = bounds[i + 1] - (float(lot["cross_half"]) if i < bounds.size() - 2 else 4.0)
				var n := int(floor((b - a) / float(lot["pitch"])))
				var start: float = a + (b - a - n * float(lot["pitch"])) / 2.0
				for k in n:
					var cx: float = start + (k + 0.5) * float(lot["pitch"])
					var cy: float = float(st["y"]) + side * (float(lot["road_half"]) + float(lot["depth"]) / 2.0 + 1.0)
					out.append({"street": st["id"], "side": side, "x": cx, "y": cy, "seg": i, "seq": seq,
						"w": float(lot["width"]), "d": float(lot["depth"]), "taken": false})
					seq += 1
	return out


func _nearest_free(cands: Array, street: String, side: int, x: float, span: int) -> int:
	var best := -1
	var best_d := INF
	for i in cands.size():
		var c: Dictionary = cands[i]
		if c["taken"] or c["street"] != street or c["side"] != side:
			continue
		# a span needs consecutive free lots in the same segment
		var ok := true
		for s in range(1, span):
			var j := i + s
			if j >= cands.size() or cands[j]["taken"] or cands[j]["street"] != street or cands[j]["side"] != side or cands[j]["seg"] != c["seg"]:
				ok = false
		if not ok:
			continue
		var cx: float = c["x"] + (span - 1) * float(spec["lot"]["pitch"]) / 2.0
		var d := absf(cx - x)
		if d < best_d:
			best_d = d
			best = i
	return best


func _build() -> void:
	var cands := _candidates()
	var lot_w: float = spec["lot"]["pitch"]
	for lm in spec["landmarks"]:
		var span := int(lm["span"])
		var i := _nearest_free(cands, lm["street"], int(lm["side"]), float(lm["x"]), span)
		if i < 0:
			push_error("No lot for %s" % lm["id"])
			continue
		var first: Dictionary = cands[i]
		var last: Dictionary = cands[i + span - 1]
		for s in span:
			cands[i + s]["taken"] = true
		var e := {"id": lm["id"], "name": lm["name"], "kind": lm["kind"], "street": lm["street"],
			"x": (first["x"] + last["x"]) / 2.0, "y": first["y"], "w": float(spec["lot"]["width"]) + (span - 1) * lot_w,
			"d": first["d"], "side": first["side"]}
		if lm.has("owner"):
			e["owner"] = lm["owner"]
		lots.append(e)
	# fill with ordinary houses, spreading evenly (deterministic), up to the target
	var free: Array = []
	for c in cands:
		if not c["taken"]:
			free.append(c)
	var need: int = int(spec["target_lots"]) - lots.size()
	var n := 0
	var stride := float(free.size()) / maxf(need, 1)
	for k in need:
		var c: Dictionary = free[int(floor(k * stride))]
		c["taken"] = true
		lots.append({"id": "house_%03d" % n, "name": "House", "kind": "house", "street": c["street"], "x": c["x"], "y": c["y"],
			"w": c["w"], "d": c["d"], "side": c["side"]})
		n += 1
	for c in cands:
		if not c["taken"]:
			lots.append({"id": "green_%03d" % by_id.size(), "name": "Garden / green", "kind": "green", "street": c["street"],
				"x": c["x"], "y": c["y"], "w": c["w"], "d": c["d"], "side": c["side"]})
			by_id[lots[-1]["id"]] = lots[-1]
	for l in lots:
		by_id[l["id"]] = l


func built_lots() -> Array:
	return lots.filter(func(l): return l["kind"] != "green")


func land_area() -> float:
	var b: Dictionary = spec["bounds"]
	return (float(b["x1"]) - float(b["x0"])) * (float(b["y1"]) - float(b["y0"]))


## Low Mercy lies under the lake as a mirror of the Rise (lore: the Overlay).
func mirror(p: Vector2, shore_y: float = -130.0) -> Vector2:
	return Vector2(p.x, 2.0 * shore_y - p.y)


func walk_seconds(a: String, b: String) -> float:
	var pa := Vector2(by_id[a]["x"], by_id[a]["y"])
	var pb := Vector2(by_id[b]["x"], by_id[b]["y"])
	return (absf(pa.x - pb.x) + absf(pa.y - pb.y)) / float(spec["walk_speed_mps"])
