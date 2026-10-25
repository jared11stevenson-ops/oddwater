extends Control
## Dusting for prints by hand: swipe the brush across the surface and the powder clings to hidden ridges. Enough of the surface
## brushed and the pad reports back; the HUD then asks the game what the powder found. The ridge picture is only decoration:
## it is the same for every surface and tells you nothing about who touched it.

signal brushed(coverage: float)

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const COLS := 26
const ROWS := 12

var title := "Surface"
var _cells := PackedByteArray()
var _t := 0.0
var _fired := false
var _swipe := false


func _init() -> void:
	name = "DustPad"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 260)
	_cells.resize(COLS * ROWS)


func coverage() -> float:
	var n := 0
	for c in _cells:
		n += 1 if c > 0 else 0
	return float(n) / float(COLS * ROWS)


func brush_at(p: Vector2) -> void:
	var r := _rect()
	var cx := int((p.x - r.position.x) / r.size.x * COLS)
	var cy := int((p.y - r.position.y) / r.size.y * ROWS)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < COLS and y >= 0 and y < ROWS:
				_cells[y * COLS + x] = 1
	if not _fired and coverage() >= 0.6:
		_fired = true
		brushed.emit(coverage())
	queue_redraw()


func _rect() -> Rect2:
	return Rect2(Vector2(10, 34), size - Vector2(20, 44))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_swipe = e.pressed
		if e.pressed:
			brush_at(e.position)
	elif e is InputEventMouseMotion and _swipe:
		brush_at(e.position)
	elif e is InputEventScreenTouch:
		_swipe = e.pressed
		if e.pressed:
			brush_at(e.position)
	elif e is InputEventScreenDrag:
		brush_at(e.position)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.92))
	draw_string(font, Vector2(14, 26), "%s  ·  swipe to brush the powder  ·  %d%%" % [title, int(coverage() * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	var r := _rect()
	draw_rect(r, Color("2b2833"))
	var cw := r.size.x / COLS
	var ch := r.size.y / ROWS
	for y in ROWS:
		for x in COLS:
			if _cells[y * COLS + x] > 0:
				var c := Rect2(r.position + Vector2(x * cw, y * ch), Vector2(cw + 1, ch + 1))
				draw_rect(c, Color("8a8794"))
				# ridge arcs where the powder has settled
				var ctr := c.get_center()
				draw_arc(ctr, ch * (0.2 + 0.12 * ((x + y) % 3)), 0.0, PI * 1.2, 8, Color("d9d6e0", 0.8), 2.0)
	draw_rect(r, PAPER, false, 3.0)
