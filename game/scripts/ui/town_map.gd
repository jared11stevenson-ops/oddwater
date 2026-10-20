extends Control
## The town from above: streets, lots and every resident as a dot that walks between places. Drag to pan, pinch / wheel / buttons to zoom,
## tap a place to select it. Paper-and-ink look, lake wash in the north.

signal place_tapped(id: String)

const Base = preload("res://scripts/ui/town_base.gd")
const Portrait = preload("res://scripts/art/portrait.gd")
const INK := Color("14121c")
const TINTS := [[6.0, Color("ffeede")], [7.6, Color("ffffff")], [16.8, Color("ffffff")], [18.4, Color("ffdcc0")], [19.8, Color("8d95d6")], [22.0, Color("6169b4")], [24.0, Color("565eaa")]]

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
var base: Control
var night := 0.0
var _tokens: Dictionary = {}       # person id -> portrait traits (for the head tokens)


func setup(the_game: RefCounted) -> void:
	game = the_game
	layout = the_game.layout
	_lots_sorted = layout.lots.filter(func(l): return l["kind"] != "green")
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	base = Base.new()
	base.m = self
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.show_behind_parent = true      # the art sits behind the people, labels and windows drawn by this node
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(redraw_all)
	update_tint()
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
	update_tint()
	queue_redraw()
	anim = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float): anim = v; queue_redraw(), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)


func focus_on(id: String) -> void:
	if cur_pos.has(id):
		center = cur_pos[id]
	redraw_all()


func set_zoom(z: float) -> void:
	zoom = clampf(z, 0.7, 6.0)
	redraw_all()


func redraw_all() -> void:
	if base != null:
		base.queue_redraw()
	queue_redraw()


## Light follows the clock: warm dawn, clear day, orange dusk, blue night with lit windows.
func update_tint() -> void:
	var h: float = game.sim.hour_now()
	var col: Color = TINTS[0][1]
	for i in TINTS.size() - 1:
		var a: Array = TINTS[i]
		var b: Array = TINTS[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			col = (a[1] as Color).lerp(b[1], (h - float(a[0])) / (float(b[0]) - float(a[0])))
	if h > 24.0:
		col = TINTS[-1][1]
	base.modulate = col
	night = clampf((19.2 - h) / -2.0, 0.0, 1.0) if h >= 19.2 else (clampf((6.8 - h) / 0.8, 0.0, 1.0) if h < 6.8 else 0.0)


func _token(id: String) -> Dictionary:
	if not _tokens.has(id):
		_tokens[id] = Portrait.traits_for(game.sim.people[id])
	return _tokens[id]


func _draw() -> void:
	var sc := s()
	var font := ThemeDB.fallback_font
	# lit windows after dark
	if night > 0.05:
		for l in layout.lots:
			if l["kind"] == "green" or l["kind"] == "park":
				continue
			var h := hash(String(l["id"]))
			if h % 100 < 78:
				var c := to_screen(Vector2(float(l["x"]), float(l["y"])))
				if c.x < -20 or c.y < -20 or c.x > size.x + 20 or c.y > size.y + 20:
					continue
				var wsz := Vector2(3.4, 3.0) * sc
				draw_rect(Rect2(c + Vector2(-5.0, -2.0) * sc, wsz), Color(1.0, 0.82, 0.3, night))
				if h % 2 == 0:
					draw_rect(Rect2(c + Vector2(2.5, -2.0) * sc, wsz), Color(1.0, 0.82, 0.3, night))
	# selection
	var sel: Dictionary = layout.by_id.get(selected, {})
	if not sel.is_empty():
		var tl := to_screen(Vector2(float(sel["x"]) - float(sel["w"]) / 2.0, float(sel["y"]) - float(sel["d"]) / 2.0))
		draw_rect(Rect2(tl, Vector2(float(sel["w"]), float(sel["d"])) * sc).grow(3.0), Color("f5b82e"), false, 4.0)
	# place names, big ones first, skipping any that would overlap
	var label_boxes: Array = []
	var named: Array = layout.lots.filter(func(x): return x["kind"] == "landmark" or x["kind"] == "park")
	named.sort_custom(func(a, b): return float(a["w"]) > float(b["w"]))
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
		draw_rect(Rect2(lr.position - Vector2(3, 1), lr.size + Vector2(6, 3)), Color(0.95, 0.91, 0.82, 0.78))
		draw_string(font, tl2 + Vector2(2, -4), nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	# people: small coloured dots from afar, little faces when you zoom in
	var rad := clampf(2.4 * sc, 3.5, 10.0)
	var host: String = game.host
	var heads := sc >= 1.5
	for id in cur_pos:
		if id == host:
			continue
		var a: Vector2 = prev_pos.get(id, cur_pos[id])
		var sp := to_screen(a.lerp(cur_pos[id], anim))
		if sp.x < -20 or sp.y < -20 or sp.x > size.x + 20 or sp.y > size.y + 20:
			continue
		if night > 0.5 and game.sim.people[id].activity == "sleep":
			continue          # tucked up indoors: only the lit window shows
		if heads:
			Portrait.draw_token(self, sp, clampf(2.6 * sc, 6.0, 13.0), _token(id))
		else:
			var mood: float = game.sim.people[id].mood() / 100.0
			draw_circle(sp, rad, Color("d95f4a").lerp(Color("5fa35a"), mood))
			draw_arc(sp, rad, 0.0, TAU, 12, INK, 1.0)
	if cur_pos.has(host):
		var hp := to_screen((prev_pos.get(host, cur_pos[host]) as Vector2).lerp(cur_pos[host], anim))
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(hp, rad * 2.6 * pulse, Color(0.96, 0.72, 0.18, 0.3))
		Portrait.draw_token(self, hp, maxf(rad * 1.9, 9.0), _token(host), true)
		var nm: String = String(game.sim.people[host].display).split(" ")[0]
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var tag := Rect2(hp + Vector2(-tw / 2.0 - 6.0, -rad * 2.4 - 28.0), Vector2(tw + 12.0, 26.0))
		draw_rect(tag, Color("f5b82e"))
		draw_rect(tag, INK, false, 2.0)
		draw_string(font, tag.position + Vector2(6, 20), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)


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
		redraw_all()
	elif e is InputEventMagnifyGesture:
		set_zoom(zoom * (e as InputEventMagnifyGesture).factor)
	elif e is InputEventPanGesture:
		center += (e as InputEventPanGesture).delta * 6.0 / s()
		redraw_all()


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
