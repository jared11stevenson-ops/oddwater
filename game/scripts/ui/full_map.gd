extends Control
## The full-screen map: a stylised top-down Little Mercy. Lake, roads, the park, every building as a footprint coloured by what it is, place
## names that thin out as you zoom out, your arrow with its heading, the crime scene pulsing red, the next objective, your home, the homes of
## your persons of interest, the cameras you know about, the newcomers. Drag to pan, pinch / wheel / buttons to zoom, tap a place for its card.
## It reads only what MapData allows (case file, notebook, directory), never the private truth.

signal travel_requested(lot: String)
signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TownTheme = preload("res://scripts/ui/town_theme.gd")
const MapData = preload("res://scripts/ui/map_data.gd")
const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const MARIGOLD := Color("f5b82e")
const VIOLET := Color("4a3f7a")
const RED := Color("e23d3d")
const GREEN := Color("3f7a4f")
const LAND := Color("efe4c6")
const WILD := Color("d3d9b0")
const WATER := Color("8fc4cf")
const WATER_DEEP := Color("62a5b8")
const ROAD := Color("fbf4df")
const ROAD_EDGE := Color("b9a780")
const TOP_H := 68.0

var game: RefCounted
var layout: RefCounted
var zoom := 1.0
var center := Vector2(0, 180)
var selected := ""
var player_world := Vector2.INF
var player_yaw := 0.0
var objective_lot := ""
var show_legend := false
var night := 0.0
var markers: Array = []
var card: PanelContainer
var go_scene: Button
var legend_panel: PanelContainer
var close_btn: Button
var title_lbl: Label
var _touches := {}
var _pinch_d := 0.0
var _pinching := false
var _drag := false
var _moved := 0.0
var _labels_cache: Array = []
var _lots: Array = []
var _safe := Vector4(24, 6, 24, 12)


func setup(the_game: RefCounted, objective: String = "") -> void:
	game = the_game
	layout = game.layout
	objective_lot = objective
	name = "FullMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_lots = layout.lots.duplicate()
	markers = MapData.markers(game, objective_lot)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_chrome()
	resized.connect(_layout)
	var sc := String(game.case.get("scene", ""))
	if sc != "" and layout.by_id.has(sc) and not game.solved():
		focus_lot(sc)
	elif player_world != Vector2.INF:
		center = player_world
	_layout()


func base_scale() -> float:
	return minf(size.x / 1000.0, size.y / 700.0)


func s() -> float:
	return base_scale() * zoom


func to_screen(w: Vector2) -> Vector2:
	return size / 2.0 + (w - center) * s()


func to_world(p: Vector2) -> Vector2:
	return (p - size / 2.0) / s() + center


func lot_pos(lot: String) -> Vector2:
	var l: Dictionary = layout.by_id.get(lot, {})
	return Vector2(float(l["x"]), float(l["y"])) if not l.is_empty() else Vector2.INF


func focus_lot(lot: String) -> void:
	var p := lot_pos(lot)
	if p != Vector2.INF:
		center = p
	queue_redraw()


func set_zoom(z: float, pivot: Vector2 = Vector2.INF) -> void:
	var nz := clampf(z, 0.55, 9.0)
	if pivot == Vector2.INF:
		pivot = size / 2.0
	var w := to_world(pivot)
	zoom = nz
	center = w - (pivot - size / 2.0) / s()
	queue_redraw()


## Pinch by a factor about a screen point, and pan by a screen delta (also what the touch handling calls; tests call these too).
func pinch(factor: float, at: Vector2 = Vector2.INF) -> void:
	set_zoom(zoom * factor, at)


func pan_by(screen_delta: Vector2) -> void:
	center -= screen_delta / s()
	queue_redraw()


# ------------------------------------------------------------------ chrome: top bar, buttons, card, legend
func _btn(text: String, nm: String, cb: Callable, px: int, w: float, h: float) -> Button:
	var b := Button.new()
	b.text = text
	b.name = nm
	b.clip_text = false
	b.add_theme_font_size_override("font_size", UiKit.fs(px))
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	UiKit.set_button_style(b, PAPER, INK, INK)
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	add_child(b)
	return b


func _build_chrome() -> void:
	var bar := ColorRect.new()
	bar.name = "MapBar"
	bar.color = Color(0.08, 0.07, 0.11, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	title_lbl = Label.new()
	TownTheme.heading(title_lbl, UiKit.fs(34), PAPER)
	title_lbl.name = "MapTitle"
	title_lbl.text = "LITTLE MERCY"
	bar.add_child(title_lbl)
	close_btn = _btn("Close", "MapClose", func(): closed.emit(), 26, 140, 56)
	UiKit.set_button_style(close_btn, INK, MARIGOLD, PAPER)
	go_scene = _btn("Go to scene", "MapGoScene", _go_scene, 28, 300, 72)
	UiKit.set_button_style(go_scene, RED, INK, PAPER)
	go_scene.visible = false
	_btn("+", "MapZoomIn", func(): set_zoom(zoom * 1.5), 34, 64, 64)
	_btn("-", "MapZoomOut", func(): set_zoom(zoom / 1.5), 34, 64, 64)
	_btn("Me", "MapMe", _center_on_me, 22, 64, 64)
	_btn("Key", "MapLegend", _toggle_legend, 22, 64, 64)
	card = PanelContainer.new()
	card.name = "MapCard"
	card.add_theme_stylebox_override("panel", UiKit.box(PAPER, INK, 4, 12, 14))
	card.visible = false
	add_child(card)
	legend_panel = PanelContainer.new()
	legend_panel.name = "MapLegendPanel"
	legend_panel.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 12))
	legend_panel.visible = false
	add_child(legend_panel)
	_fill_legend()


func _layout() -> void:
	_safe = UiKit.safe_margins(self)
	var bar: Control = get_node("MapBar")
	bar.position = Vector2.ZERO
	bar.size = Vector2(size.x, TOP_H)
	title_lbl.position = Vector2(_safe.x + 6.0, 12.0)
	close_btn.position = Vector2(size.x - _safe.z - 150.0, 6.0)
	var lx := _safe.x + 8.0
	var bottom := size.y - _safe.w - 8.0
	go_scene.position = Vector2(lx, bottom - 72.0)
	var col := bottom - (84.0 if go_scene.visible else 0.0)
	for nm in ["MapMe", "MapLegend", "MapZoomOut", "MapZoomIn"]:
		var b: Control = get_node(nm)
		b.position = Vector2(lx, col - 64.0)
		col -= 72.0
	_place_card()
	legend_panel.position = Vector2(lx + 80.0, TOP_H + 10.0)
	queue_redraw()


func _place_card() -> void:
	var w := minf(440.0, size.x * 0.4)
	card.custom_minimum_size = Vector2(w, 0)
	card.size = Vector2(w, 10)
	card.position = Vector2(size.x - _safe.z - w - 8.0, TOP_H + 10.0)


func refresh(objective: String = "") -> void:
	if objective != "":
		objective_lot = objective
	markers = MapData.markers(game, objective_lot)
	var sc := String(game.case.get("scene", ""))
	var sm := lot_pos(sc)
	go_scene.visible = sc != "" and not game.solved() and sm != Vector2.INF
	if go_scene.visible:
		var mins := _minutes_to(sc)
		go_scene.text = "Go to scene" + ("  %s" % UiKit.minutes_text(mins) if mins > 0 else "  (you are here)")
		go_scene.disabled = game.phase != "day"
	night = clampf((game.sim.hour_now() - 18.5) / 2.0, 0.0, 1.0) if game.sim.hour_now() >= 18.5 else (clampf((6.5 - game.sim.hour_now()) / 1.0, 0.0, 1.0) if game.sim.hour_now() < 6.5 else 0.0)
	title_lbl.text = "LITTLE MERCY  ·  %s  ·  Day %d" % [load("res://scripts/sim/brief.gd").clock_text(game.sim.hour_now()), game.sim.day]
	_layout()
	if selected != "":
		show_card(selected)
	queue_redraw()


func _meters_to(lot: String) -> float:
	var p := lot_pos(lot)
	if p == Vector2.INF:
		return 0.0
	var from := player_world if player_world != Vector2.INF else lot_pos(String(game.me().location))
	return from.distance_to(p) if from != Vector2.INF else 0.0


func _minutes_to(lot: String) -> int:
	return MapData.minutes_for(_meters_to(lot))


func _go_scene() -> void:
	var sc := String(game.case.get("scene", ""))
	if sc != "":
		travel_requested.emit(sc)


func _center_on_me() -> void:
	if player_world != Vector2.INF:
		center = player_world
		queue_redraw()


func _toggle_legend() -> void:
	show_legend = not show_legend
	legend_panel.visible = show_legend


func _lbl(parent: Control, text: String, px: int, color: Color = INK, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiKit.fs(px))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(card.custom_minimum_size.x - 40.0 if parent == card or parent.get_parent() == card else 0.0, 0)
	parent.add_child(l)
	return l


func _fill_legend() -> void:
	for c in legend_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	legend_panel.add_child(v)
	var h := Label.new()
	TownTheme.heading(h, UiKit.fs(28), RED)
	h.text = "LEGEND"
	v.add_child(h)
	for k in ["home", "shop", "bar", "office", "clinic", "library", "school", "chapel", "hall", "park"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var sw := ColorRect.new()
		sw.color = MapData.STYLE_COLORS[k]
		sw.custom_minimum_size = Vector2(26, 20)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var l := Label.new()
		l.text = MapData.STYLE_NAMES[k]
		l.add_theme_font_size_override("font_size", UiKit.fs(19))
		l.add_theme_color_override("font_color", INK)
		row.add_child(l)
	var items := [["scene", "Crime scene"], ["objective", "Next stop"], ["home", "Your home"], ["poi", "Person of interest's home"], ["camera", "Camera you know"], ["new", "Newcomer's house"], ["me", "You"]]
	for it in items:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		v.add_child(row2)
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(26, 24)
		var kind: String = it[0]
		ic.draw.connect(func(): _draw_icon(ic, kind, Vector2(13, 12), 0.0))
		row2.add_child(ic)
		var l2 := Label.new()
		l2.text = it[1]
		l2.add_theme_font_size_override("font_size", UiKit.fs(19))
		l2.add_theme_color_override("font_color", INK)
		row2.add_child(l2)


# ------------------------------------------------------------------ the card
func show_card(id: String) -> void:
	selected = id
	var l: Dictionary = layout.by_id.get(id, {})
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	if l.is_empty():
		card.visible = false
		return
	card.visible = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var scene := String(game.case.get("scene", ""))
	var nm := MapData.label_for(game, l)
	if nm == "":
		nm = "A house on %s" % String(l.get("street", "")).capitalize().replace("_", " ")
	var h := Label.new()
	h.name = "CardName"
	TownTheme.heading(h, UiKit.fs(34), INK)
	h.text = nm
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.custom_minimum_size = Vector2(card.custom_minimum_size.x - 40.0, 0)
	v.add_child(h)
	var m := _meters_to(id)
	var mins := MapData.minutes_for(m)
	var sub := "%s  ·  %s" % [MapData.type_name(l), ("%d m" % int(round(m))) if m >= 12.0 else "you are here"]
	var sl := _lbl(v, sub, 20, VIOLET)
	sl.name = "CardSub"
	if id == scene and not game.solved():
		UiKit.stamp(v, "CRIME SCENE", RED, 18, true)
	if id == objective_lot and id != scene:
		UiKit.stamp(v, "NEXT STOP", VIOLET, 18, true)
	var res := MapData.residents_known(game, id)
	if MapData.is_house(l):
		if res.is_empty():
			var u := _lbl(v, "Residents: not in your notebook.", 20)
			u.name = "CardWho"
		else:
			var w := _lbl(v, "Lives here: " + ", ".join(res.map(func(x): return String(game.sim.people[x].display))), 21)
			w.name = "CardWho"
	var wk := MapData.workers_known(game, id)
	if not wk.is_empty():
		var ww := _lbl(v, "Works here: " + ", ".join(wk.map(func(x): return String(game.sim.people[x].display))), 21)
		ww.name = "CardWorks"
	for cam in game.cameras():
		if String(cam["lot"]) == id:
			_lbl(v, "Camera: %s" % String(cam["label"]), 19, GREEN)
	for n in game.newcomers:
		if String(n["home"]) == id:
			_lbl(v, "New in town: %s, %s." % [n["name"], n["job"]], 20, GREEN)
	_lbl(v, "Visited." if MapData.visited(game, id) else "You have not been inside yet.", 19, VIOLET)
	var b := Button.new()
	b.name = "MapTravel"
	b.clip_text = false
	b.add_theme_font_size_override("font_size", UiKit.fs(28))
	b.custom_minimum_size = Vector2(0, 72)
	UiKit.press_fx(b)
	if game.phase != "day":
		b.text = "Too late to travel"
		b.disabled = true
	elif not MapData.travel_known(game, l):
		b.text = "Not a place you know yet"
		b.disabled = true
	elif m < 12.0:
		b.text = "Step to the door"
	else:
		b.text = ("Go to scene  %s" % UiKit.minutes_text(mins)) if id == scene else ("Travel there  %s" % UiKit.minutes_text(mins))
	UiKit.set_button_style(b, RED if id == scene else INK, INK, PAPER)
	b.pressed.connect(func(): travel_requested.emit(id))
	v.add_child(b)
	card.size = Vector2(card.custom_minimum_size.x, 10)
	queue_redraw()


func hide_card() -> void:
	selected = ""
	card.visible = false
	queue_redraw()


# ------------------------------------------------------------------ input
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 2:
				var pts: Array = _touches.values()
				_pinch_d = (pts[0] as Vector2).distance_to(pts[1])
				_pinching = true
				_drag = false
		else:
			_touches.erase(st.index)
			if _touches.is_empty():
				_pinching = false
		return
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var pts2: Array = _touches.values()
			var d := (pts2[0] as Vector2).distance_to(pts2[1])
			var mid := ((pts2[0] as Vector2) + (pts2[1] as Vector2)) / 2.0
			if _pinch_d > 8.0:
				pinch(d / _pinch_d, mid)
			_pinch_d = d
			pan_by(sd.relative / 2.0)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			pinch(1.2, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			pinch(1.0 / 1.2, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = not _pinching
				_moved = 0.0
			else:
				if _drag and _moved < 14.0 and not _pinching:
					tap(mb.position)
				_drag = false
	elif e is InputEventMouseMotion and _drag and not _pinching:
		var mm := e as InputEventMouseMotion
		_moved += mm.relative.length()
		pan_by(mm.relative)
	elif e is InputEventMagnifyGesture:
		var mg := e as InputEventMagnifyGesture
		pinch(mg.factor, mg.position)
	elif e is InputEventPanGesture:
		pan_by(-(e as InputEventPanGesture).delta * 8.0)


## What is under a finger: a marker first (generous reach), then the nearest building.
func lot_at(p: Vector2) -> String:
	var best := ""
	var best_d := 40.0
	for mk in markers:
		var c := to_screen(lot_pos(String(mk["lot"])))
		var d := c.distance_to(p)
		if d < best_d:
			best_d = d
			best = String(mk["lot"])
	if best != "":
		return best
	best_d = 26.0
	var sc := s()
	for l in _lots:
		if String(l["kind"]) == "green":
			continue
		var c2 := to_screen(Vector2(float(l["x"]), float(l["y"])))
		var half := Vector2(float(l["w"]), float(l["d"])) * sc * 0.5
		var dx := maxf(absf(p.x - c2.x) - half.x, 0.0)
		var dy := maxf(absf(p.y - c2.y) - half.y, 0.0)
		var dd := sqrt(dx * dx + dy * dy)
		if dd < best_d:
			best_d = dd
			best = String(l["id"])
	return best


func tap(p: Vector2) -> void:
	var id := lot_at(p)
	if id == "":
		hide_card()
		return
	UiKit.haptic(12)
	show_card(id)


# ------------------------------------------------------------------ drawing
func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var sc := s()
	var t := Time.get_ticks_msec() * 0.001
	var font := TownTheme.bold()
	draw_rect(Rect2(Vector2.ZERO, size), WILD)
	var bounds: Dictionary = layout.spec["bounds"]
	var tl := to_screen(Vector2(float(bounds["x0"]) - 20.0, -122.0))
	var br := to_screen(Vector2(float(bounds["x1"]) + 20.0, float(bounds["y1"]) + 20.0))
	draw_rect(Rect2(tl, br - tl), LAND)
	_draw_lake(sc, t)
	_draw_roads(sc)
	_draw_lots(sc)
	_draw_route(sc, t)
	_draw_labels(sc, font)
	_draw_markers(sc, t, font)
	_draw_player(sc, t)
	if night > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.3, 0.28 * night))


func _draw_lake(sc: float, t: float) -> void:
	var shore := to_screen(Vector2(0, -122)).y
	var top := minf(-10.0, shore - 800.0)
	draw_rect(Rect2(0, top, size.x, shore - top), WATER)
	draw_rect(Rect2(0, top, size.x, (shore - top) * 0.5), WATER_DEEP)
	for i in 5:
		var y := shore - (16.0 + i * 15.0) * sc
		var pts := PackedVector2Array()
		for x in range(-20, int(size.x) + 30, 20):
			pts.append(Vector2(x, y + sin(float(x) * 0.04 + i * 1.7 + t * 0.6) * 3.0 * sc))
		if pts.size() > 1:
			draw_polyline(pts, Color(1, 1, 1, 0.38), maxf(1.3, 1.5 * sc), true)
	var sp := PackedVector2Array()
	for x in range(-20, int(size.x) + 30, 14):
		sp.append(Vector2(x, shore + sin(float(x) * 0.07) * 2.0 * sc))
	if sp.size() > 1:
		draw_polyline(sp, INK, maxf(2.0, 2.4 * sc), true)
	if shore > 40.0 and shore < size.y:
		var f := TownTheme.bold()
		draw_string(f, Vector2(size.x * 0.5 - 90.0, shore - 36.0 * sc - 8.0), "Lake Mercy", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.fs(26), Color(1, 1, 1, 0.8))


func _draw_roads(sc: float) -> void:
	var spec: Dictionary = layout.spec
	var half := 6.5 * sc
	var streets: Array = spec["streets"]
	var y0 := float(streets[0]["y"])
	var y1 := float(streets[-1]["y"])
	for edge in [true, false]:
		var col := ROAD_EDGE if edge else ROAD
		var hw := half + (2.0 if edge else 0.0)
		for st in streets:
			var a := to_screen(Vector2(float(st["x0"]), float(st["y"])))
			var b := to_screen(Vector2(float(st["x1"]), float(st["y"])))
			draw_rect(Rect2(a.x, a.y - hw, b.x - a.x, hw * 2.0), col)
		for cx in spec["cross_x"]:
			var a2 := to_screen(Vector2(float(cx), y0))
			var b2 := to_screen(Vector2(float(cx), y1))
			draw_rect(Rect2(a2.x - hw, a2.y, hw * 2.0, b2.y - a2.y), col)
	if sc > 0.9:
		for st in streets:
			var a3 := to_screen(Vector2(float(st["x0"]), float(st["y"])))
			var b3 := to_screen(Vector2(float(st["x1"]), float(st["y"])))
			var x := maxf(a3.x, -20.0)
			while x < minf(b3.x, size.x + 20.0):
				draw_line(Vector2(x, a3.y), Vector2(x + 8.0 * sc, a3.y), ROAD_EDGE, maxf(1.0, sc * 0.9))
				x += 20.0 * sc


func _draw_lots(sc: float) -> void:
	for l in _lots:
		var c := to_screen(Vector2(float(l["x"]), float(l["y"])))
		var kind := String(l["kind"])
		var wd := float(l["w"])
		var dp := float(l["d"])
		if c.x < -140 or c.y < -140 or c.x > size.x + 140 or c.y > size.y + 140:
			continue
		if kind == "green" or kind == "park":
			var r := Rect2(c - Vector2(wd, dp) * sc * 0.5, Vector2(wd, dp) * sc)
			draw_rect(r, Color("b7d594") if kind == "green" else Color("9cc87c"))
			draw_rect(r, Color(0.2, 0.35, 0.2, 0.5), false, 1.5)
			var n := 4 if kind == "green" else 14
			for i in n:
				var h := hash("%s%d" % [l["id"], i])
				var tp := c + Vector2(float((h >> 3) % 100) / 100.0 - 0.5, float((h >> 11) % 100) / 100.0 - 0.5) * Vector2(wd, dp) * sc * 0.85
				draw_circle(tp, maxf(2.5, 3.6 * sc), Color("5d9150"))
				draw_arc(tp, maxf(2.5, 3.6 * sc), 0, TAU, 10, Color(0.1, 0.25, 0.12, 0.8), 1.2)
			continue
		var house := MapData.is_house(l)
		var fw := wd * (0.62 if house else 0.9)
		var fd := dp * (0.5 if house else 0.8)
		# the footprint sits on the street side of the lot
		var side := float(l.get("side", 1))
		var off := Vector2(0, -side * (dp - fd) * 0.4 * sc)
		var fr := Rect2(c + off - Vector2(fw, fd) * sc * 0.5, Vector2(fw, fd) * sc)
		var col := MapData.color_of(l)
		draw_rect(Rect2(fr.position + Vector2(2.5, 3.0), fr.size), Color(0.2, 0.15, 0.3, 0.22))
		draw_rect(fr, col)
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(2.0, fr.size.y * 0.22))), col.lightened(0.28))
		draw_rect(fr, INK, false, maxf(1.5, 2.0 * minf(sc, 1.6)))
		if String(l["id"]) == selected:
			draw_rect(fr.grow(5.0), MARIGOLD, false, 4.0)
		if MapData.visited(game, String(l["id"])) and sc > 1.1 and not house:
			draw_circle(fr.end - Vector2(6, 6), 5.0, GREEN)
			draw_polyline(PackedVector2Array([fr.end - Vector2(9, 6), fr.end - Vector2(6.5, 3), fr.end - Vector2(3, 9)]), PAPER, 1.6, true)


func _draw_route(sc: float, t: float) -> void:
	if selected == "" or player_world == Vector2.INF:
		return
	var a := to_screen(player_world)
	var b := to_screen(lot_pos(selected))
	var d := (b - a)
	var n := int(d.length() / 16.0)
	for i in range(0, n, 2):
		var p0 := a + d * (float(i) + fmod(t * 3.0, 2.0)) / float(maxi(n, 1))
		var p1 := a + d * minf(float(i) + 1.0 + fmod(t * 3.0, 2.0), float(n)) / float(maxi(n, 1))
		draw_line(p0, p1, Color(0.29, 0.25, 0.48, 0.85), 3.0, true)


func _draw_labels(sc: float, font: Font) -> void:
	var fs := UiKit.fs(17)
	var cands: Array = []
	var scene := String(game.case.get("scene", ""))
	for l in _lots:
		var kind := String(l["kind"])
		if kind == "green":
			continue
		var id := String(l["id"])
		var nm := MapData.label_for(game, l)
		if nm == "":
			continue
		var pr := 10.0 + float(l["w"]) / 10.0
		if id == selected:
			pr = 200.0
		elif id == scene:
			pr = 150.0
		elif id == objective_lot:
			pr = 140.0
		elif id == String(game.me().home):
			pr = 120.0
		elif MapData.is_house(l):
			if zoom < 2.2 and id != selected:
				continue
			pr = 30.0
		elif kind == "park":
			pr = 60.0
		cands.append({"l": l, "pr": pr, "nm": nm})
	cands.sort_custom(func(a, b): return a["pr"] > b["pr"])
	var boxes: Array = []
	for cd in cands:
		var l: Dictionary = cd["l"]
		var c := to_screen(Vector2(float(l["x"]), float(l["y"])))
		var fd := float(l["d"]) * (0.5 if MapData.is_house(l) else 0.8)
		var below := c + Vector2(0, (float(l["d"]) * 0.5 + 1.0) * sc * (1.0 if float(l.get("side", 1)) > 0.0 else 1.0))
		var tsz := font.get_string_size(cd["nm"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(below.x - tsz.x / 2.0, below.y + tsz.y * 0.55)
		if String(l["kind"]) != "park" and float(l.get("side", 1)) < 0.0:
			pos.y = c.y - (float(l["d"]) * 0.5) * sc - tsz.y * 0.25
		var r := Rect2(pos + Vector2(0, -tsz.y * 0.8), tsz)
		if r.end.x < 0 or r.position.x > size.x or r.end.y < TOP_H or r.position.y > size.y:
			continue
		var hit := false
		for o in boxes:
			if (o as Rect2).intersects(r.grow(3.0)):
				hit = true
				break
		if hit and cd["pr"] < 100.0:
			continue
		boxes.append(r)
		draw_string_outline(font, pos, cd["nm"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(PAPER, 0.95))
		draw_string(font, pos, cd["nm"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	_labels_cache = boxes


func _draw_icon(ci: CanvasItem, kind: String, p: Vector2, t: float) -> void:
	match kind:
		"scene":
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			ci.draw_circle(p, 14.0 + 9.0 * pulse, Color(RED, 0.28 * (1.0 - pulse) + 0.1))
			ci.draw_circle(p, 10.0, RED)
			ci.draw_arc(p, 10.0, 0, TAU, 20, INK, 2.5, true)
			ci.draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), PAPER, 2.5)
			ci.draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), PAPER, 2.5)
		"objective":
			var pts := PackedVector2Array([p + Vector2(0, -12), p + Vector2(10, 0), p + Vector2(0, 12), p + Vector2(-10, 0)])
			ci.draw_colored_polygon(pts, MARIGOLD)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2.5, true)
		"home":
			var roof := PackedVector2Array([p + Vector2(-11, -1), p + Vector2(0, -11), p + Vector2(11, -1)])
			ci.draw_colored_polygon(roof, MARIGOLD)
			ci.draw_rect(Rect2(p + Vector2(-8, -1), Vector2(16, 11)), MARIGOLD)
			ci.draw_rect(Rect2(p + Vector2(-8, -1), Vector2(16, 11)), INK, false, 2.0)
			ci.draw_polyline(roof, INK, 2.0, true)
		"poi":
			ci.draw_circle(p + Vector2(0, -3), 9.0, VIOLET)
			ci.draw_arc(p + Vector2(0, -3), 9.0, 0, TAU, 16, INK, 2.0, true)
			ci.draw_circle(p + Vector2(0, -6), 3.0, PAPER)
			ci.draw_arc(p + Vector2(0, 5), 5.0, PI, TAU, 8, PAPER, 2.5, true)
		"camera":
			ci.draw_rect(Rect2(p + Vector2(-9, -6), Vector2(14, 11)), Color("2f8f9d"))
			ci.draw_rect(Rect2(p + Vector2(-9, -6), Vector2(14, 11)), INK, false, 2.0)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(5, -2), p + Vector2(11, -6), p + Vector2(11, 6), p + Vector2(5, 2)]), Color("2f8f9d"))
			ci.draw_circle(p + Vector2(-2, 0), 2.5, PAPER)
		"new":
			var st := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + float(i) * PI / 5.0
				st.append(p + Vector2(cos(a), sin(a)) * (10.0 if i % 2 == 0 else 4.5))
			ci.draw_colored_polygon(st, GREEN)
			ci.draw_polyline(st + PackedVector2Array([st[0]]), INK, 1.8, true)
		"me":
			var tri := PackedVector2Array([p + Vector2(0, -11), p + Vector2(9, 9), p + Vector2(0, 4), p + Vector2(-9, 9)])
			ci.draw_colored_polygon(tri, MARIGOLD)
			ci.draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 2.5, true)


func _draw_markers(sc: float, t: float, font: Font) -> void:
	var inner := Rect2(Vector2(20, TOP_H + 16), size - Vector2(40, TOP_H + 36))
	var scene := String(game.case.get("scene", ""))
	var order := ["camera", "new", "poi", "home", "objective", "scene"]
	for k in order:
		for mk in markers:
			if String(mk["kind"]) != k:
				continue
			var lot := String(mk["lot"])
			var wp := lot_pos(lot)
			var sp := to_screen(wp) + Vector2(0, -float(layout.by_id[lot]["d"]) * sc * 0.12)
			if inner.has_point(sp):
				_draw_icon(self, k, sp, t)
			elif k in ["scene", "objective"]:
				_edge_arrow(sp, inner, RED if k == "scene" else MARIGOLD, "SCENE" if k == "scene" else "NEXT", font)
	if scene != "" and selected == scene:
		pass


func _edge_arrow(target: Vector2, inner: Rect2, col: Color, label: String, font: Font) -> void:
	var c := inner.get_center()
	var d := target - c
	var k := minf((inner.size.x / 2.0) / maxf(absf(d.x), 0.001), (inner.size.y / 2.0) / maxf(absf(d.y), 0.001))
	var rim := c + d * k
	var dir := d.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([rim + dir * 14.0, rim - dir * 10.0 + perp * 13.0, rim - dir * 10.0 - perp * 13.0])
	draw_colored_polygon(tri, col)
	draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 2.5, true)
	var lp := rim - dir * 26.0 - Vector2(24, -6)
	draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.fs(16), 6, Color(PAPER, 0.95))
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.fs(16), INK)


func _draw_player(sc: float, t: float) -> void:
	if player_world == Vector2.INF:
		return
	var hp := to_screen(player_world)
	var pulse := 1.0 + 0.14 * sin(t * 6.0)
	draw_circle(hp, 20.0 * pulse, Color(MARIGOLD, 0.32))
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var tri := PackedVector2Array([hp + fwd * 18.0, hp - fwd * 11.0 + side * 12.0, hp - fwd * 5.0, hp - fwd * 11.0 - side * 12.0])
	draw_colored_polygon(tri, MARIGOLD)
	draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 3.0, true)
