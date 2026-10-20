extends Control
## The town from above: streets, lots and every resident as a dot that walks between places. Drag to pan, pinch / wheel / buttons to zoom,
## tap a place to select it. Paper-and-ink look, lake wash in the north.

signal place_tapped(id: String)

const KIND_FILL := {"house": Color("ead9b0"), "home": Color("e3c98f"), "landmark": Color("d49a74"), "park": Color("a9cf93"), "green": Color("cfe0b5")}
const INK := Color("14121c")
const WATER := Color("9cc9d2")
const LAND := Color("f1e6c8")
const STREET := Color("c9b88f")

var layout: RefCounted
var game: RefCounted
var zoom := 1.0
var center := Vector2(0, 175)
var selected := ""
var prev_pos: Dictionary = {}
var cur_pos: Dictionary = {}
var anim := 1.0
var _press := Vector2.ZERO
var _dragging := false
var _moved := 0.0
var _lots_sorted: Array = []


func setup(the_game: RefCounted) -> void:
	game = the_game
	layout = the_game.layout
	_lots_sorted = layout.lots.filter(func(l): return l["kind"] != "green")
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	snapshot()
	refresh_positions()
	anim = 1.0


func base_scale() -> float:
	return minf(size.x / 1000.0, size.y / 700.0)


func s() -> float:
	return base_scale() * zoom


func to_screen(w: Vector2) -> Vector2:
	return size / 2.0 + (w - center) * s()


func to_world(p: Vector2) -> Vector2:
	return (p - size / 2.0) / s() + center


func _offset(id: String, lot: Dictionary) -> Vector2:
	var h := hash(id)
	var fx := float((h >> 3) % 1000) / 1000.0 - 0.5
	var fy := float((h >> 13) % 1000) / 1000.0 - 0.5
	return Vector2(fx * (float(lot["w"]) - 6.0), fy * (float(lot["d"]) - 6.0))


func _pos_of(id: String) -> Vector2:
	var p: RefCounted = game.sim.people[id]
	var lot: Dictionary = layout.by_id.get(p.location, {})
	if lot.is_empty():
		return Vector2.INF
	return Vector2(float(lot["x"]), float(lot["y"])) + _offset(id, lot)


## Remember where everyone is, so the next refresh can walk them to where they end up.
func snapshot() -> void:
	prev_pos = cur_pos.duplicate()


func refresh_positions() -> void:
	cur_pos = {}
	for id in game.sim.order:
		if game.sim.alive(game.sim.people[id]):
			var w := _pos_of(id)
			if w != Vector2.INF:
				cur_pos[id] = w


func animate_to_now(seconds: float = 0.7) -> void:
	refresh_positions()
	anim = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float): anim = v; queue_redraw(), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)


func focus_on(id: String) -> void:
	if cur_pos.has(id):
		center = cur_pos[id]
	queue_redraw()


func set_zoom(z: float) -> void:
	zoom = clampf(z, 0.7, 6.0)
	queue_redraw()


func _draw() -> void:
	var sc := s()
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	# the lake, north of the shore road
	var lake_bottom := to_screen(Vector2(0, -122)).y
	draw_rect(Rect2(0, minf(0.0, lake_bottom - 2000.0), size.x, lake_bottom - minf(0.0, lake_bottom - 2000.0)), WATER)
	for i in 4:
		var y := lake_bottom - 22.0 * sc * (i + 1)
		var pts := PackedVector2Array()
		for x in range(0, int(size.x) + 24, 24):
			pts.append(Vector2(x, y + sin(x * 0.03 + i) * 3.0 * sc))
		if pts.size() > 1:
			draw_polyline(pts, Color(1, 1, 1, 0.35), maxf(1.0, sc))
	# streets
	var spec: Dictionary = layout.spec
	var streets: Array = spec["streets"]
	for st in streets:
		draw_line(to_screen(Vector2(float(st["x0"]), float(st["y"]))), to_screen(Vector2(float(st["x1"]), float(st["y"]))), STREET, 12.0 * sc)
	var y0: float = float(streets[0]["y"]); var y1: float = float(streets[-1]["y"])
	for cx in spec["cross_x"]:
		draw_line(to_screen(Vector2(float(cx), y0)), to_screen(Vector2(float(cx), y1)), STREET, 12.0 * sc)
	# lots
	var font := ThemeDB.fallback_font
	var label_boxes: Array = []
	var named: Array = layout.lots.filter(func(x): return x["kind"] == "landmark" or x["kind"] == "park")
	named.sort_custom(func(a, b): return float(a["w"]) > float(b["w"]))      # big places get their label first
	for l in layout.lots:
		var tl := to_screen(Vector2(float(l["x"]) - float(l["w"]) / 2.0, float(l["y"]) - float(l["d"]) / 2.0))
		var r := Rect2(tl, Vector2(float(l["w"]), float(l["d"])) * sc)
		if r.end.x < -40 or r.position.x > size.x + 40 or r.end.y < -40 or r.position.y > size.y + 40:
			continue
		var kind: String = l["kind"]
		draw_rect(r, KIND_FILL.get(kind, KIND_FILL["house"]))
		if kind != "green":
			draw_rect(r, INK, false, maxf(1.0, 1.4 * minf(sc, 2.0)))
		if l["id"] == selected:
			draw_rect(r.grow(3.0), Color("f5b82e"), false, 4.0)
	for l in named:
		var tl2 := to_screen(Vector2(float(l["x"]) - float(l["w"]) / 2.0, float(l["y"]) - float(l["d"]) / 2.0))
		var fs := int(clampf(14.0 * sc, 13.0, 26.0))
		var nm2: String = String(l["name"])
		var tsz := font.get_string_size(nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var lr := Rect2(tl2 + Vector2(2, -4 - tsz.y), tsz)
		if lr.end.x < 0 or lr.position.x > size.x or lr.end.y < 0 or lr.position.y > size.y:
			continue
		var clash := false
		for o in label_boxes:
			if (o as Rect2).intersects(lr.grow(2.0)):
				clash = true
				break
		if clash and l["id"] != selected:
			continue
		label_boxes.append(lr)
		draw_string(font, tl2 + Vector2(2, -4), nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	# people
	var rad := clampf(2.4 * sc, 3.5, 10.0)
	var host: String = game.host
	for id in cur_pos:
		var a: Vector2 = prev_pos.get(id, cur_pos[id])
		var w: Vector2 = a.lerp(cur_pos[id], anim)
		var sp := to_screen(w)
		if sp.x < -20 or sp.y < -20 or sp.x > size.x + 20 or sp.y > size.y + 20:
			continue
		var m: float = game.sim.people[id].mood() / 100.0
		var col := Color("d95f4a").lerp(Color("5fa35a"), m)
		if id == host:
			continue
		draw_circle(sp, rad, col)
		draw_arc(sp, rad, 0.0, TAU, 12, INK, 1.0)
	if cur_pos.has(host):
		var hp := to_screen((prev_pos.get(host, cur_pos[host]) as Vector2).lerp(cur_pos[host], anim))
		var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(hp, rad * 2.4 * pulse, Color(0.96, 0.72, 0.18, 0.35))
		draw_circle(hp, rad * 1.7, Color("f5b82e"))
		draw_arc(hp, rad * 1.7, 0.0, TAU, 20, INK, 2.5)
		var nm: String = String(game.sim.people[host].display).split(" ")[0]
		draw_string(font, hp + Vector2(-20, -rad * 2.6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)


func _process(_d: float) -> void:
	if visible and cur_pos.has(game.host):
		queue_redraw()      # the host pulses


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom(zoom * 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(zoom / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragging = true
				_moved = 0.0
			else:
				_dragging = false
				if _moved < 14.0:
					tap(mb.position)
	elif e is InputEventMouseMotion and _dragging:
		var mm := e as InputEventMouseMotion
		_moved += mm.relative.length()
		center -= mm.relative / s()
		queue_redraw()
	elif e is InputEventMagnifyGesture:
		set_zoom(zoom * (e as InputEventMagnifyGesture).factor)
	elif e is InputEventPanGesture:
		center += (e as InputEventPanGesture).delta * 6.0 / s()
		queue_redraw()


## Nearest built lot to a screen point, with a generous finger-sized tolerance.
func lot_at(p: Vector2, tolerance: float = 44.0) -> String:
	var best := ""
	var best_d := tolerance
	var sc := s()
	for l in _lots_sorted:
		var c := to_screen(Vector2(float(l["x"]), float(l["y"])))
		var half := Vector2(float(l["w"]), float(l["d"])) * sc / 2.0
		var dx := maxf(absf(p.x - c.x) - half.x, 0.0)
		var dy := maxf(absf(p.y - c.y) - half.y, 0.0)
		var d := sqrt(dx * dx + dy * dy)
		if d < best_d or (d == best_d and l["kind"] == "landmark"):
			best_d = d
			best = l["id"]
	return best


func tap(p: Vector2) -> void:
	var id := lot_at(p)
	if id != "":
		selected = id
		place_tapped.emit(id)
		queue_redraw()
