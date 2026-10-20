extends RefCounted
## Walking routes along the town's street grid (five east-west streets, five cross streets). People keep to the sidewalks.

const LANE := 6.4        # distance of the sidewalk from a street's centre line

var ys: Array = []       # east-west street z positions
var xs: Array = []       # cross-street x positions
var x_min := -480.0
var x_max := 480.0


func _init(spec: Dictionary) -> void:
	for st in spec["streets"]:
		ys.append(float(st["y"]))
	for cx in spec["cross_x"]:
		xs.append(float(cx))
	x_min = float(spec["streets"][0]["x0"])
	x_max = float(spec["streets"][0]["x1"])


func nearest_street(z: float) -> int:
	var best := 0
	for i in ys.size():
		if absf(float(ys[i]) - z) < absf(float(ys[best]) - z):
			best = i
	return best


func _side(z: float, y: float) -> float:
	return 1.0 if z >= y else -1.0


## A list of waypoints from `a` to `b`, along sidewalks.
func route(a: Vector3, b: Vector3) -> Array:
	var ia := nearest_street(a.z)
	var ib := nearest_street(b.z)
	var za: float = float(ys[ia]) + _side(a.z, float(ys[ia])) * LANE
	var zb: float = float(ys[ib]) + _side(b.z, float(ys[ib])) * LANE
	var out: Array = [a, Vector3(a.x, 0.0, za)]
	if ia == ib or absf(a.x - b.x) < 1.0 and absf(a.z - b.z) < 14.0:
		out.append(Vector3(b.x, 0.0, za))
		out.append(Vector3(b.x, 0.0, zb))
		out.append(b)
		return out
	var best_x: float = float(xs[0])
	var best := INF
	for cx in xs:
		var c := absf(a.x - float(cx)) + absf(b.x - float(cx))
		if c < best:
			best = c
			best_x = float(cx)
	var off := LANE if a.x >= best_x else -LANE
	var off_b := LANE if b.x >= best_x else -LANE
	out.append(Vector3(best_x + off, 0.0, za))
	out.append(Vector3(best_x + off_b, 0.0, zb))
	out.append(Vector3(b.x, 0.0, zb))
	out.append(b)
	return out


static func length(path: Array) -> float:
	var d := 0.0
	for i in range(1, path.size()):
		d += (path[i] as Vector3).distance_to(path[i - 1])
	return d
