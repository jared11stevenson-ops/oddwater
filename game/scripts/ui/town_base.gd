extends Control
## The static art of the town map, drawn once per view change: lake wash, inked streets, buildings with roofs and printed shadows,
## trees and lawns. The map tints this whole layer for dawn, dusk and night. Hand-inked look: every outline wobbles a little, in a
## deterministic way, and heavier at the silhouette.

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const ROOFS := [Color("b4584a"), Color("a2503f"), Color("c97a52"), Color("7a6a8a"), Color("5f7f8c"), Color("8f6a4a"), Color("b0665a")]
const LANDMARK_ROOFS := [Color("c9573f"), Color("2f8f9d"), Color("d19a2e"), Color("6d5a9a"), Color("4f8a5f"), Color("b85a7a"), Color("3d5a80")]
const WALL := Color("efe0bd")
const LAWNS := [Color("c9dcae"), Color("c0d7a2"), Color("d0e0b4"), Color("bdd49c")]
const ROAD := Color("c9b590")
const WATER := Color("8fc4cf")
const WATER_DEEP := Color("5ea2b4")
const LAND := Color("f4ead0")

var m: Control      # the TownMap


func _wob(a: Vector2, b: Vector2, seed_s: String, amt: float) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var h := hash(seed_s)
	for i in 2:
		var f := float(i + 1) / 3.0
		var j := float((h >> (i * 7)) & 63) / 63.0 - 0.5
		var n := (b - a).orthogonal().normalized()
		out.append(a.lerp(b, f) + n * j * amt)
	out.append(b)
	return out


func _inked_rect(r: Rect2, seed_s: String, w: float, amt: float = 1.1) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var pts := PackedVector2Array()
	for i in 4:
		pts.append_array(_wob(c[i], c[(i + 1) % 4], seed_s + str(i), amt))
	draw_polyline(pts, INK, w, true)


func _halftone_rect(r: Rect2, step: float, col: Color) -> void:
	var y := r.position.y + step * 0.5
	var row := 0
	while y < r.end.y:
		var x := r.position.x + (step * 0.5 if row % 2 == 1 else 0.0) + step * 0.25
		while x < r.end.x:
			draw_circle(Vector2(x, y), step * 0.26, col)
			x += step
		y += step * 0.866
		row += 1


func _tree(p: Vector2, r: float, seed_s: String) -> void:
	draw_circle(p + Vector2(r * 0.35, r * 0.4), r, Color(0.29, 0.25, 0.48, 0.25))     # printed shadow
	var green := Color("78a35e").lerp(Color("5f8f50"), float(hash(seed_s) % 100) / 100.0)
	draw_circle(p, r, green)
	draw_arc(p + Vector2(-r * 0.15, -r * 0.15), r * 0.55, deg_to_rad(200), deg_to_rad(300), 8, green.lightened(0.3), maxf(1.0, r * 0.25), true)
	draw_arc(p, r, 0.0, TAU, 18, INK, maxf(1.4, r * 0.2), true)


func _draw() -> void:
	if m == null or m.layout == null:
		return
	var sc: float = m.s()
	var lw := clampf(2.0 * sc, 1.4, 3.6)
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	_lake(sc)
	_streets(sc, lw)
	var layout: RefCounted = m.layout
	for l in layout.lots:
		var tl: Vector2 = m.to_screen(Vector2(float(l["x"]) - float(l["w"]) / 2.0, float(l["y"]) - float(l["d"]) / 2.0))
		var r := Rect2(tl, Vector2(float(l["w"]), float(l["d"])) * sc)
		if r.end.x < -30 or r.position.x > size.x + 30 or r.end.y < -30 or r.position.y > size.y + 30:
			continue
		match String(l["kind"]):
			"green": _green(r, l, sc)
			"park": _park(r, l, sc, lw)
			"landmark": _landmark(r, l, sc, lw)
			_: _house(r, l, sc, lw)


func _lake(sc: float) -> void:
	var shore_y: float = m.to_screen(Vector2(0, -122)).y
	var top := minf(-50.0, shore_y - 900.0)
	draw_rect(Rect2(0, top, size.x, shore_y - top), WATER)
	draw_rect(Rect2(0, top, size.x, (shore_y - top) * 0.55), WATER_DEEP)
	# wash: soft wide blooms that bleed past each other (the lake is painted, the town is printed)
	for i in 8:
		var cx := fmod(float(i) * 233.0 + 60.0, maxf(size.x, 1.0))
		var cy := shore_y - (18.0 + float((i * 37) % 50)) * sc
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(3.2, 0.5))
		draw_circle(Vector2.ZERO, (30.0 + (i % 4) * 10.0) * sc, Color(1, 1, 1, 0.09))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 5:
		var y := shore_y - 14.0 * sc * (i + 1)
		var pts := PackedVector2Array()
		for x in range(-20, int(size.x) + 30, 18):
			pts.append(Vector2(x, y + sin(float(x) * 0.045 + i * 1.7) * 3.2 * sc))
		if pts.size() > 1:
			draw_polyline(pts, Color(1, 1, 1, 0.42), maxf(1.2, 1.6 * sc), true)
	# shoreline: a wobbling ink line with little reeds
	var sp := PackedVector2Array()
	for x in range(-20, int(size.x) + 30, 14):
		sp.append(Vector2(x, shore_y + sin(float(x) * 0.07) * 2.2 * sc))
	if sp.size() > 1:
		draw_polyline(sp, INK, maxf(2.0, 2.4 * sc), true)
	for x in range(0, int(size.x), int(maxf(34.0, 52.0 * sc))):
		var rb := Vector2(x + (hash(x) % 17), shore_y + 3.0 * sc)
		draw_line(rb, rb + Vector2(-2, -8.0 * sc), Color("5f8f50"), maxf(1.4, sc * 1.6), true)
		draw_line(rb, rb + Vector2(3, -6.0 * sc), Color("5f8f50"), maxf(1.4, sc * 1.6), true)


func _streets(sc: float, lw: float) -> void:
	var spec: Dictionary = m.layout.spec
	var streets: Array = spec["streets"]
	var half := 6.0 * sc
	for st in streets:
		var a: Vector2 = m.to_screen(Vector2(float(st["x0"]), float(st["y"])))
		var b: Vector2 = m.to_screen(Vector2(float(st["x1"]), float(st["y"])))
		draw_rect(Rect2(a.x, a.y - half, b.x - a.x, half * 2.0), ROAD)
	var y0: float = float(streets[0]["y"])
	var y1: float = float(streets[-1]["y"])
	for cx in spec["cross_x"]:
		var a2: Vector2 = m.to_screen(Vector2(float(cx), y0))
		var b2: Vector2 = m.to_screen(Vector2(float(cx), y1))
		draw_rect(Rect2(a2.x - half, a2.y, half * 2.0, b2.y - a2.y), ROAD)
	var thin := maxf(1.0, lw * 0.55)
	for st in streets:
		var a: Vector2 = m.to_screen(Vector2(float(st["x0"]), float(st["y"])))
		var b: Vector2 = m.to_screen(Vector2(float(st["x1"]), float(st["y"])))
		draw_line(Vector2(a.x, a.y - half), Vector2(b.x, b.y - half), INK, thin, true)
		draw_line(Vector2(a.x, a.y + half), Vector2(b.x, b.y + half), INK, thin, true)
		var x := a.x
		while x < b.x:
			draw_line(Vector2(x, a.y), Vector2(x + 9.0 * sc, a.y), PAPER, maxf(1.2, 1.6 * sc), true)
			x += 20.0 * sc
	for cx in spec["cross_x"]:
		var a2: Vector2 = m.to_screen(Vector2(float(cx), y0))
		var b2: Vector2 = m.to_screen(Vector2(float(cx), y1))
		draw_line(Vector2(a2.x - half, a2.y), Vector2(b2.x - half, b2.y), INK, thin, true)
		draw_line(Vector2(a2.x + half, a2.y), Vector2(b2.x + half, b2.y), INK, thin, true)
	# cover the crossing outlines where roads meet: paint each junction square back over the lines
	for st in streets:
		for cx in spec["cross_x"]:
			var j: Vector2 = m.to_screen(Vector2(float(cx), float(st["y"])))
			draw_rect(Rect2(j.x - half + 0.8, j.y - half + 0.8, half * 2.0 - 1.6, half * 2.0 - 1.6), ROAD)


func _green(r: Rect2, l: Dictionary, sc: float) -> void:
	var lawn: Color = LAWNS[hash(String(l["id"])) % LAWNS.size()]
	draw_rect(r.grow(-1.0), lawn)
	var h := hash(String(l["id"]))
	for i in 3:
		var p := r.position + Vector2(r.size.x * (0.2 + 0.3 * float((h >> (i * 4)) & 3) / 3.0), r.size.y * (0.25 + 0.25 * float((h >> (i * 5)) & 3) / 3.0))
		draw_line(p, p + Vector2(-2, -5) * sc, Color("78a35e"), maxf(1.2, sc * 1.5), true)
		draw_line(p, p + Vector2(2, -5) * sc, Color("78a35e"), maxf(1.2, sc * 1.5), true)
	if h % 3 == 0:
		_tree(r.get_center(), 6.0 * sc, String(l["id"]))


func _park(r: Rect2, l: Dictionary, sc: float, lw: float) -> void:
	draw_rect(r, Color("a9cf93"))
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), ROAD, 6.0 * sc, true)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), ROAD, 6.0 * sc, true)
	var pond := r.get_center() + Vector2(r.size.x * 0.22, r.size.y * 0.18)
	draw_circle(pond, 7.0 * sc, WATER)
	draw_arc(pond, 7.0 * sc, 0.0, TAU, 14, INK, lw * 0.8, true)
	for i in 7:
		var h := hash(String(l["id"]) + str(i))
		_tree(r.position + Vector2(r.size.x * (0.08 + 0.84 * float(h % 100) / 100.0), r.size.y * (0.12 + 0.76 * float((h >> 8) % 100) / 100.0)), 5.5 * sc, str(i))
	_inked_rect(r, String(l["id"]), lw * 1.2)


## Which way a lot faces: houses south of a street face north (toward it), houses north of a street face south.
func _faces_up(l: Dictionary) -> bool:
	return int(l.get("side", 1)) == 1


func _house(r: Rect2, l: Dictionary, sc: float, lw: float) -> void:
	var id := String(l["id"])
	var h := hash(id)
	draw_rect(r.grow(-0.5), LAWNS[h % LAWNS.size()])
	var up := _faces_up(l)
	var body := Rect2(r.position + Vector2(r.size.x * 0.17, r.size.y * (0.22 if up else 0.08)), Vector2(r.size.x * 0.66, r.size.y * 0.66))
	# printed shadow, with halftone dots
	var sh := Rect2(body.position + Vector2(body.size.x, 3.0 * sc), Vector2(5.0 * sc, body.size.y))
	draw_rect(sh, Color(0.29, 0.25, 0.48, 0.22))
	if sc >= 0.8:
		_halftone_rect(sh, 3.2, Color(0.29, 0.25, 0.48, 0.55))
	draw_rect(body, WALL)
	var roof: Color = ROOFS[(h >> 3) % ROOFS.size()]
	var rr := body.grow(1.6 * sc)
	draw_rect(rr, roof)
	# roof ridge and a lighter planes split for a cel feel
	var ridge := rr.position.y + rr.size.y * 0.5
	draw_rect(Rect2(rr.position.x, ridge, rr.size.x, rr.size.y * 0.5), roof.darkened(0.14))
	draw_line(Vector2(rr.position.x, ridge), Vector2(rr.end.x, ridge), INK, maxf(1.0, lw * 0.6), true)
	_inked_rect(rr, id, lw)
	# door on the street side, chimney
	var door_y := rr.end.y - 1.0 if not up else rr.position.y - 1.0
	draw_rect(Rect2(rr.get_center().x - 2.2 * sc, door_y - (0.0 if not up else 0.0), 4.4 * sc, 3.0 * sc), Color("e23d3d") if h % 7 == 0 else Color("6a4a3a"))
	draw_rect(Rect2(rr.position.x + rr.size.x * 0.72, rr.position.y + rr.size.y * 0.12, 3.6 * sc, 3.6 * sc), Color("5a4a48"))
	# garden
	if h % 3 != 0:
		_tree(Vector2(r.position.x + r.size.x * 0.1, r.end.y - r.size.y * (0.15 if up else 0.85)), 4.4 * sc, id)
	if h % 4 == 0:
		_tree(Vector2(r.end.x - r.size.x * 0.1, r.end.y - r.size.y * (0.14 if up else 0.86)), 3.8 * sc, id + "b")


func _landmark(r: Rect2, l: Dictionary, sc: float, lw: float) -> void:
	var id := String(l["id"])
	var h := hash(id)
	draw_rect(r.grow(-0.5), Color("e4dcc0"))
	var body := r.grow(-r.size.y * 0.06)
	body = Rect2(body.position + Vector2(0, r.size.y * 0.04), body.size - Vector2(0, r.size.y * 0.04))
	var sh := Rect2(body.position + Vector2(body.size.x, 3.5 * sc), Vector2(5.5 * sc, body.size.y))
	draw_rect(sh, Color(0.29, 0.25, 0.48, 0.24))
	if sc >= 0.8:
		_halftone_rect(sh, 3.2, Color(0.29, 0.25, 0.48, 0.55))
	var roof: Color = LANDMARK_ROOFS[h % LANDMARK_ROOFS.size()]
	draw_rect(body, roof)
	var ridge := body.position.y + body.size.y * 0.5
	draw_rect(Rect2(body.position.x, ridge, body.size.x, body.size.y * 0.5), roof.darkened(0.16))
	draw_line(Vector2(body.position.x, ridge), Vector2(body.end.x, ridge), INK, maxf(1.0, lw * 0.6), true)
	# awning stripes along the front
	var up := _faces_up(l)
	var ay := body.position.y if up else body.end.y - 3.5 * sc
	var n := maxi(3, int(body.size.x / (5.0 * sc)))
	for i in n:
		draw_rect(Rect2(body.position.x + body.size.x * float(i) / n, ay, body.size.x / n, 3.5 * sc), Color("f3e9d2") if i % 2 == 0 else Color("e23d3d"))
	_inked_rect(body, id, lw * 1.25)
	# a flagpole on the bigger civic places
	if float(l["w"]) > 60.0:
		var fp := Vector2(body.end.x - 5.0 * sc, body.position.y - 1.0)
		draw_line(fp, fp + Vector2(0, -9.0 * sc), INK, maxf(1.2, 1.4 * sc), true)
		draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -9.0 * sc), fp + Vector2(6.0 * sc, -7.0 * sc), fp + Vector2(0, -5.0 * sc)]), Color("e23d3d"))
